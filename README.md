# hierarchical-settings.sql
using hierarchical settings with user-defined type


`setting_item` has `path` (ltree) to track hierarchy to be aggreated into
`setting_t`. the root path (`subpath(path,0,1)`) is the children attribute,
while `key` (text) is grand-children keys, and `value` (jsonb) to be aggregated.
(see example in `dml/setting_t.sql`)

`ddl.sql` contains `setting_item` definition

`dml/setting-api.sql` contains common CRUD operation on `setting_item` table

`dml/setting_it.sql` a UDT for searching `setting_items`

`dml/setting_t.sql` returns aggregated `setting_items`
