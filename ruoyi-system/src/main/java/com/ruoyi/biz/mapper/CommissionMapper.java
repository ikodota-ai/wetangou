package com.ruoyi.biz.mapper;

import java.util.Date;
import java.util.List;
import java.util.Map;
import com.ruoyi.biz.domain.Commission;

/**
 * 佣金Mapper接口
 *
 * @author dytuangou
 * @date 2026-07-24
 */
public interface CommissionMapper
{
    public Commission selectCommissionByCommissionId(Long commissionId);

    public List<Commission> selectCommissionList(Commission commission);

    public int insertCommission(Commission commission);

    public int updateCommission(Commission commission);

    public int deleteCommissionByCommissionId(Long commissionId);

    public int deleteCommissionByCommissionIds(Long[] commissionIds);

    /**
     * 结算冷静期到期的佣金（status=0 且 create_time + #{settleDays}天 <= NOW）
     * 把 status 置为 1、settle_time = #{now}
     */
    public int settleExpiredCommissions(Map<String, Object> params);

    /**
     * 按结算时间分组查询待联动推客的佣金合计
     */
    public List<Map<String, Object>> selectSettleGroupsByTime(Date settleTime);

    /**
     * 把指定结算时间的记录标记为已联动
     */
    public int markSettledByTime(Date settleTime);
}
