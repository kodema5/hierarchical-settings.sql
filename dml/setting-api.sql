------------------------------------------------------------
-- sets a setting item implements some rules
-- root is nlevel(path) = 1
--
create procedure setting_set_item (
    path_ ltree,
    key_ text,
    value_ jsonb,
    is_root_ boolean default false
)
    language plpgsql
    set search_path from current
as $$
declare
    is_root boolean = nlevel(path_) = 1;
    has_root boolean;
begin
    -- if setting a root
    --
    if nlevel(path_) = 1 then
        if not is_root_ then
            raise exception 'is_root_override_needed';
        end if;

        insert into setting_item(path,key,value)
            values (path_, key_, value_)
            on conflict (path, key)
            do update set value = value_;

        return;
    end if;

    -- otherwise, ensure root exists
    --
    if not exists(select
        from setting_item
        where key = key_
        and path = subpath(path_, 0, 1))
    then
        raise exception 'root_key_not_found';
    end if;

    insert into setting_item(path,key,value)
        values (path_, key_, value_)
        on conflict (path, key)
        do update set value = value_;

    return;
end;
$$;

------------------------------------------------------------
-- get a stored item
--
create function setting_get_item (
    path_ ltree,
    key_ text
)
    returns jsonb
    language sql
    set search_path from current
    stable
as $$
    select value
    from setting_item
    where path = path_
    and key = key_
$$;

------------------------------------------------------------
-- count items with path + key
--
create function setting_item_length (
    path_ ltree,
    key_ text default null
)
    returns int
    language sql
    set search_path from current
    stable
as $$
    select count(1)
    from setting_item
    where path_ @> path
    and (key_ is null or key = key_);
$$;

------------------------------------------------------------
-- remove item(s)
--
create procedure setting_remove_item (
    path_ ltree,
    key_ text,
    is_cascade_ boolean default false
)
    language plpgsql
    set search_path from current
as $$
declare
    n int = setting_item_length(path_, key_);
begin
    if n>1 and not is_cascade_ then
        raise exception 'is_cascade_needed % items found', n;
    end if;

    delete from setting_item
    where path_ @> path
    and (key_ is null or key = key_);
end;
$$;


\if :{?test}
\if :test
    create function tests.test_setting_api()
        returns setof text
        language plpgsql
        set search_path from current
    as $$
    begin
        return next throws_ok(
            format('call setting_set_item(%L,%L,%L)',
                'app',
                'key',
                '{}'
            )
            , 'is_root_override_needed');

        return next throws_ok(
            format('call setting_set_item(%L,%L,%L)',
                'app.mod',
                'key',
                '{}'
            )
            , 'root_key_not_found');

        call setting_set_item('app', 'key', '{"a":1}', true);
        return next ok(
            setting_get_item('app', 'key') = '{"a":1}',
            'able to get item value');

        call setting_set_item('app.mod', 'key', '{"a":2}');
        call setting_set_item('app.mod.foo', 'key', '{"a":3}');
        return next ok(
            setting_item_length('app') = 3
            and setting_item_length('app.mod') = 2
            and setting_item_length('app.mod.foo') = 1,
            'get number of app items'
        );

        return next throws_ok(
            format('call setting_remove_item(%L,%L)',
                'app',
                'key'
            )
            , 'is_cascade_needed 3 items found');

        call setting_remove_item('app.mod.foo', null);
        return next ok(
            setting_item_length('app.mod.foo') = 0,
            'app.mod.foo removed');

        call setting_remove_item('app', null, true);
        return next ok(
            setting_item_length('app') = 0,
            'app.* removed');
    end;
    $$;
\endif
\endif
