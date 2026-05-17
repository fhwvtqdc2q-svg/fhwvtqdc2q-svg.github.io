-- Ameen live stock query for Al-Ameen 9 / AmnDb001.
-- Read-only. It does not write anything inside Al-Ameen.
--
-- Expected output for the sync agent:
--   item_name : material name
--   stock_qty : current stock quantity across warehouses

select
  mt.Name as item_name,
  cast(coalesce(sum(ms.Qty), max(mt.Qty), 0) as decimal(18, 3)) as stock_qty
from dbo.mt000 mt
left join dbo.ms000 ms
  on ms.MatGUID = mt.GUID
where
  mt.Name is not null
  and ltrim(rtrim(mt.Name)) <> ''
group by
  mt.GUID,
  mt.Name
order by
  mt.Name;
