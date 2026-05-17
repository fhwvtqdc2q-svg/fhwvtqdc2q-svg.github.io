-- Ameen live stock query for Al-Ameen 9 / AmnDb001.
-- Read-only. It does not write anything inside Al-Ameen.
--
-- Expected output for the sync agent:
--   item_name : material name
--   stock_qty : current stock quantity across warehouses
--   unit1_name : first/default Ameen unit name
--   unit2_name : second pricing unit name
--   unit2_factor : how many unit1 items are inside one unit2 item

select
  mt.Name as item_name,
  cast(coalesce(sum(ms.Qty), max(mt.Qty), 0) as decimal(18, 3)) as stock_qty,
  nullif(ltrim(rtrim(mt.Unity)), '') as unit1_name,
  nullif(ltrim(rtrim(mt.Unit2)), '') as unit2_name,
  cast(
    case
      when coalesce(mt.Unit2Fact, 0) > 0 then mt.Unit2Fact
      else 1
    end
    as decimal(18, 3)
  ) as unit2_factor
from dbo.mt000 mt
left join dbo.ms000 ms
  on ms.MatGUID = mt.GUID
where
  mt.Name is not null
  and ltrim(rtrim(mt.Name)) <> ''
group by
  mt.GUID,
  mt.Name,
  mt.Unity,
  mt.Unit2,
  mt.Unit2Fact
order by
  mt.Name;
