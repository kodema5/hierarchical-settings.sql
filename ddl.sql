------------------------------------------------------------
-- tracks the hierarchical setting values
--
create table if not exists setting_item (
    path ltree,
    key text,
    primary key(path, key),

    value jsonb
);
