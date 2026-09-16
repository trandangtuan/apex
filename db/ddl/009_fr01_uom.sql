-- FR-01: Unit of measure master table, so ITEM.uom becomes a governed lookup
-- (select list) instead of free text.
-- Target schema: ADMIN (parsing schema of APEX app 105 / 26house)

set define off

--------------------------------------------------------------------------------
-- UOM
--------------------------------------------------------------------------------
create table uom (
    uom_code     varchar2(10)  not null
                 constraint uom_pk primary key,
    uom_name     varchar2(60)  not null,
    is_active    char(1) default 'Y' not null,
    created_by   varchar2(60) default coalesce(sys_context('APEX$SESSION','APP_USER'), user) not null,
    created_on   date default sysdate not null,
    updated_by   varchar2(60),
    updated_on   date,
    constraint uom_active_ck check (is_active in ('Y','N'))
);
comment on table uom is 'FR-01: unit of measure master, referenced by ITEM.uom as a select list';

insert into uom (uom_code, uom_name) values ('EA', 'Each');
insert into uom (uom_code, uom_name) values ('BOX', 'Box');
insert into uom (uom_code, uom_name) values ('SET', 'Set');
insert into uom (uom_code, uom_name) values ('PCS', 'Pieces');
insert into uom (uom_code, uom_name) values ('PAIR', 'Pair');
commit;

--------------------------------------------------------------------------------
-- ITEM.uom -> UOM.uom_code
--------------------------------------------------------------------------------
alter table item
    add constraint item_uom_fk foreign key (uom) references uom (uom_code);

create index item_uom_idx on item (uom);
