------------------------------------------------------------
-- aggregate jsonb object (similar to js's object.assign)
--
create aggregate jsonb_object_agg(jsonb) (
    sfunc = 'jsonb_concat',
    stype = jsonb,
    initcond = '{}'
);

------------------------------------------------------------
-- concat array-of-objects jsonb
--
create function jsonb_object_agg(jsonb[])
    returns jsonb
    language sql
    set search_path from current
    stable
as $$
    select jsonb_object_agg(a)
    from unnest($1) a
$$;

------------------------------------------------------------
-- the base setting_t
--
create type setting_t as (
    it_ setting_it
);

------------------------------------------------------------
-- build setting_t on aggregated jsonb setting-items
--
create function setting_t(
    it setting_it
)
    returns setting_t
    language sql
    set search_path from current
    stable
as $$
    with
    vals as (
        select
            subpath(path, 0, 1) as root,
            key,
            jsonb_object_agg(array_agg(value)) value
        from setting_items(it)
        group by root, key
    )
    select jsonb_populate_record(
        null::setting_t,
        jsonb_build_object('it_', it)
        || (
        select
            jsonb_build_object(
                root,
                jsonb_object_agg(key, value)
            )
        from vals
        group by root)
    )
$$;



------------------------------------------------------------
-- returns the attributes/keys
--
create function setting_t_keys(
    type_name_ text default null
)
    returns text[]
    language sql
    set search_path from current
    stable
as $$
    select array_agg(attname)
    from pg_attribute
    where attrelid::regclass = (coalesce(
        type_name_,
        current_schema() || '.setting_t'
    ))::regclass
    and atttypid <> 0
$$;


------------------------------------------------------------
-- drop of attribute cascade will drop setting_t also
-- below is to dynamically remove the item
--
create procedure setting_t_remove(
    keys text[],
    type_name_ text default null
)
    language plpgsql
    set search_path from current
as $$
declare
    t text = coalesce(type_name_, current_schema || '.setting_t');
    a text;
begin
    foreach a in array keys
    loop
        execute format('
            alter type %s
            drop attribute if exists %I restrict
        ', t, a);
    end loop;
end;
$$;


\if :{?test}
\if :test
    create function tests.test_setting_t()
        returns setof text
        language plpgsql
        set search_path from current
    as $$
    declare
        s setting_t;
    begin
        insert into setting_item values
            ('app', 'key1', '{"a":1,"b":1,"c":1}'),
            ('app', 'key2', '{"d":1}'),
            ('app.brand1', 'key1', '{"a":10}'),
            ('app.brand2', 'key1', '{"a":20}'),
            ('app.brand1.user1', 'key1', '{"b":200}'),
            ('app.brand1.user2', 'key1', '{"b":300}');

        create type key1_t as (
            a numeric,
            b numeric,
            c numeric
        );

        -- alter type setting_t  add attribute key1 key1_t;

        create type key2_t as (
            d numeric
        );
        -- alter type setting_t add attribute key2 key2_t;

        create type app_t as (
            key1 key1_t,
            key2 key2_t
        );
        alter type setting_t add attribute app app_t;

        return next ok(
            setting_t_keys() @> array['app'],
            'setting_t contains app attribute'
        );

        return next ok(
            setting_t_keys('app_t') @> array['key1', 'key2'],
            'app_t contains key1 and key2 attributes'
        );

        s = setting_t(setting_it('app.brand1.user1', array['key1']));
        return next ok(
            to_jsonb((s.app).key1) = '{"a":10,"b":200,"c":1}',
            'retrieves setting app.key1'
        );

        s = setting_t(setting_it('app.brand1.user1', array['key1','key2']));
        return next ok(
            ((s.app).key2).d = 1,
            'retrieves setting.key2'
        );

        call setting_t_remove(array['app']);
        return next ok(
            not (setting_t_keys() @> array['app']),
            'app has been removed from setting_t'
        );

        call setting_t_remove(array['key2'], 'app_t');
        return next ok(
            not (setting_t_keys('app_t') @> array['key2']),
            'key2 has been removed from app_t'
        );
    end;
    $$;
\endif
\endif
