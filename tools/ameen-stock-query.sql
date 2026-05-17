-- Ameen live stock query template.
-- Replace this query after we identify the real Ameen database tables.
--
-- The sync agent expects these columns:
--   item_name  : material name
--   stock_qty  : current stock quantity across the selected warehouses
--
-- Optional columns that can be added later:
--   last_sale_at
--   last_purchase_at
--   month_sold_qty

select
  cast(null as nvarchar(250)) as item_name,
  cast(null as decimal(18, 3)) as stock_qty
where 1 = 0;
