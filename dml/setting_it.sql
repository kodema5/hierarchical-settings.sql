
------------------------------------------------------------
-- for searching setting-items
--
create type setting_it as (
    path ltree,
    keys text[]
);

------------------------------------------------------------
-- creates a new setting_it
--
create function setting_it (
    path ltree,
    keys text[] default null
)
    returns setting_it
    language sql
    set search_path from current
    stable
as $$
    select (
        path,
        keys
    )::setting_it
$$;

------------------------------------------------------------
-- returns setting-items of a setting_it
--
create function setting_items (
    it setting_it
)
    returns setof setting_item
    language sql
    set search_path from current
    stable
as $$
    select *
    from setting_item
    where path @> it.path -- get all related ancestor
    and (it.keys is null or key ~ any(it.keys))
    order by nlevel(path) asc
$$;


\if :{?test}
\if :test
    create function tests.test_setting_items()
        returns setof text
        language plpgsql
        set search_path from current
    as $$
    begin
        insert into setting_item values
            ('app', 'key1', '{"a":1,"b":1,"c":1}'),
            ('app', 'key2', '{"d":1}'),
            ('app.brand1', 'key1', '{"a":10}'),
            ('app.brand2', 'key1', '{"a":20}'),
            ('app.brand1.user1', 'key1', '{"b":200}'),
            ('app.brand1.user2', 'key1', '{"b":300}');

        return next ok(
            (select count(1) from setting_items(setting_it('app'))) = 2,
            'retrieves app');

        return next ok(
            (select count(1) from setting_items(setting_it('app.brand1'))) = 3,
            'retrieves app.brand1');

        return next ok(
            (select count(1) from setting_items(setting_it('app.brand1.user1'))) = 4,
            'retrieves app.brand1.user1');

    end;
    $$;
\endif
\endif
