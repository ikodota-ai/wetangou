package com.ruoyi.framework.tenant;

import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.ruoyi.common.constant.TenantConstants;
import com.ruoyi.common.core.domain.model.TenantContext;
import net.sf.jsqlparser.expression.Expression;
import net.sf.jsqlparser.expression.ExpressionVisitorAdapter;
import net.sf.jsqlparser.expression.LongValue;
import net.sf.jsqlparser.expression.Parenthesis;
import net.sf.jsqlparser.expression.operators.conditional.AndExpression;
import net.sf.jsqlparser.expression.operators.relational.EqualsTo;
import net.sf.jsqlparser.expression.operators.relational.ParenthesedExpressionList;
import net.sf.jsqlparser.expression.operators.relational.InExpression;
import net.sf.jsqlparser.parser.CCJSqlParserUtil;
import net.sf.jsqlparser.schema.Column;
import net.sf.jsqlparser.schema.Table;
import net.sf.jsqlparser.statement.Statement;
import net.sf.jsqlparser.statement.delete.Delete;
import net.sf.jsqlparser.statement.update.Update;
import net.sf.jsqlparser.statement.select.Join;
import net.sf.jsqlparser.statement.select.ParenthesedSelect;
import net.sf.jsqlparser.statement.select.PlainSelect;
import net.sf.jsqlparser.statement.select.Select;
import net.sf.jsqlparser.statement.select.SelectItem;
import net.sf.jsqlparser.statement.select.SetOperationList;

/**
 * 租户SQL改写器：为查询语句中的业务表自动追加 merchant_id 过滤条件
 *
 * <p>基于 JSqlParser 解析AST后改写，避免字符串拼接带来的注入与误匹配风险。
 * 解析失败时返回原SQL并告警，保证功能可用性优先。</p>
 *
 * @author dytuangou
 */
public class TenantSqlRewriter
{
    private static final Logger log = LoggerFactory.getLogger(TenantSqlRewriter.class);

    /**
     * 改写SELECT语句，为租户表追加 merchant_id 条件
     *
     * @param sql 原始SQL
     * @param context 当前租户上下文
     * @return 改写后的SQL，无需改写或解析失败时返回原SQL
     */
    public static String rewrite(String sql, TenantContext context)
    {
        if (sql == null || context == null || context.isPlatform())
        {
            return sql;
        }
        // 快速判断：不含任何租户表则直接跳过解析，降低开销
        if (!containsTenantTable(sql))
        {
            return sql;
        }
        try
        {
            Statement statement = CCJSqlParserUtil.parse(sql);
            if (statement instanceof Select)
            {
                processSelect((Select) statement, context);
                return statement.toString();
            }
            if (statement instanceof Update)
            {
                processUpdate((Update) statement, context);
                return statement.toString();
            }
            if (statement instanceof Delete)
            {
                processDelete((Delete) statement, context);
                return statement.toString();
            }
            return sql;
        }
        catch (Exception e)
        {
            log.warn("[租户过滤] SQL解析失败，跳过改写。sql={}, 原因={}", sql, e.getMessage());
            return sql;
        }
    }

    /**
     * 粗粒度预判：SQL中是否出现租户表名
     */
    private static boolean containsTenantTable(String sql)
    {
        String lower = sql.toLowerCase();
        // biz_ 前缀是业务表统一约定，无此前缀直接跳过
        return lower.indexOf("biz_") >= 0;
    }

    /**
     * 处理各种select结构（普通、union、带括号的子查询）
     */
    private static void processSelect(Select select, TenantContext context)
    {
        if (select instanceof PlainSelect)
        {
            processPlainSelect((PlainSelect) select, context);
        }
        else if (select instanceof SetOperationList)
        {
            SetOperationList operationList = (SetOperationList) select;
            if (operationList.getSelects() != null)
            {
                for (Select child : operationList.getSelects())
                {
                    processSelect(child, context);
                }
            }
        }
        else if (select instanceof ParenthesedSelect)
        {
            processSelect(((ParenthesedSelect) select).getSelect(), context);
        }
    }

    /**
     * 遍历表达式中嵌套的子查询（select列、where、having等），确保子查询同样被过滤
     */
    private static void processExpression(Expression expression, final TenantContext context)
    {
        if (expression == null)
        {
            return;
        }
        expression.accept(new ExpressionVisitorAdapter()
        {
            @Override
            public void visit(net.sf.jsqlparser.statement.select.Select select)
            {
                processSelect(select, context);
            }
        });
    }

    /**
     * 处理单条select：主表 + join表 分别追加条件
     */
    private static void processPlainSelect(PlainSelect plainSelect, TenantContext context)
    {
        Expression where = plainSelect.getWhere();

        // select列中的标量子查询
        if (plainSelect.getSelectItems() != null)
        {
            for (SelectItem<?> selectItem : plainSelect.getSelectItems())
            {
                processExpression(selectItem.getExpression(), context);
            }
        }

        // where / having 中的子查询
        processExpression(where, context);
        processExpression(plainSelect.getHaving(), context);

        // 主表
        if (plainSelect.getFromItem() instanceof Table)
        {
            Table table = (Table) plainSelect.getFromItem();
            if (TenantTableRegistry.isTenantTable(table.getName()))
            {
                where = appendCondition(where, buildCondition(table, context));
            }
        }
        else if (plainSelect.getFromItem() instanceof ParenthesedSelect)
        {
            processSelect(((ParenthesedSelect) plainSelect.getFromItem()).getSelect(), context);
        }

        // join表：条件追加到 join 的 on 上，避免影响左连接语义
        if (plainSelect.getJoins() != null)
        {
            for (Join join : plainSelect.getJoins())
            {
                if (join.getRightItem() instanceof Table)
                {
                    Table joinTable = (Table) join.getRightItem();
                    if (TenantTableRegistry.isTenantTable(joinTable.getName()))
                    {
                        Expression condition = buildCondition(joinTable, context);
                        if (join.getOnExpressions() != null && !join.getOnExpressions().isEmpty())
                        {
                            List<Expression> newOnExpressions = new ArrayList<Expression>();
                            for (Expression on : join.getOnExpressions())
                            {
                                newOnExpressions.add(new AndExpression(on, condition));
                            }
                            join.setOnExpressions(newOnExpressions);
                        }
                        else
                        {
                            // 逗号连接等无on条件的情况，退化为追加到where
                            where = appendCondition(where, condition);
                        }
                    }
                }
                else if (join.getRightItem() instanceof ParenthesedSelect)
                {
                    processSelect(((ParenthesedSelect) join.getRightItem()).getSelect(), context);
                }
            }
        }

        plainSelect.setWhere(where);
    }

    /**
     * 处理UPDATE：追加 merchant_id 条件，防止跨商户改数据
     */
    private static void processUpdate(Update update, TenantContext context)
    {
        Table table = update.getTable();
        if (table == null || !TenantTableRegistry.isTenantTable(table.getName()))
        {
            return;
        }
        update.setWhere(appendCondition(update.getWhere(), buildCondition(table, context)));
    }

    /**
     * 处理DELETE：追加 merchant_id 条件，防止跨商户删数据
     */
    private static void processDelete(Delete delete, TenantContext context)
    {
        Table table = delete.getTable();
        if (table == null || !TenantTableRegistry.isTenantTable(table.getName()))
        {
            return;
        }
        delete.setWhere(appendCondition(delete.getWhere(), buildCondition(table, context)));
    }

    /**
     * 构造 merchant_id 过滤条件
     *
     * <p>强隔离表：merchant_id = ?；共享表：merchant_id in (0, ?)；
     * 代理商：merchant_id in (名下商户...)。</p>
     */
    private static Expression buildCondition(Table table, TenantContext context)
    {
        Column column = new Column(table.getAlias() != null
                ? table.getAlias().getName() + "." + TenantConstants.COLUMN_MERCHANT_ID
                : table.getName() + "." + TenantConstants.COLUMN_MERCHANT_ID);

        boolean shared = TenantTableRegistry.isSharedTable(table.getName());

        if (context.isAgent())
        {
            List<Long> merchantIds = context.getMerchantIds();
            ParenthesedExpressionList<Expression> values = new ParenthesedExpressionList<Expression>();
            if (shared)
            {
                values.add(new LongValue(TenantConstants.PLATFORM_MERCHANT_ID));
            }
            if (merchantIds == null || merchantIds.isEmpty())
            {
                // 代理商名下无商户时用不可能命中的值，避免越权看到全量数据
                values.add(new LongValue(-1L));
            }
            else
            {
                for (Long merchantId : merchantIds)
                {
                    values.add(new LongValue(merchantId));
                }
            }
            InExpression in = new InExpression(column, values);
            return new Parenthesis(in);
        }

        Long merchantId = context.getMerchantId() == null ? -1L : context.getMerchantId();
        if (shared)
        {
            ParenthesedExpressionList<Expression> values = new ParenthesedExpressionList<Expression>();
            values.add(new LongValue(TenantConstants.PLATFORM_MERCHANT_ID));
            values.add(new LongValue(merchantId));
            return new Parenthesis(new InExpression(column, values));
        }

        EqualsTo equalsTo = new EqualsTo();
        equalsTo.setLeftExpression(column);
        equalsTo.setRightExpression(new LongValue(merchantId));
        return equalsTo;
    }

    /**
     * 以 AND 追加条件
     */
    private static Expression appendCondition(Expression where, Expression condition)
    {
        if (where == null)
        {
            return condition;
        }
        return new AndExpression(new Parenthesis(where), condition);
    }

    private TenantSqlRewriter()
    {
    }
}
