-- =====================================================================
--  V1 — первая версия схемы: ветропарк, турбины, датчики, телеметрия, события.
--  Применить:  make migrate        Снести и применить заново:  make migrate-reset
--  После применения V1 НЕ редактируется — изменения идут в V2, V3, ...
-- =====================================================================
create schema if not exists project;
set search_path = project;

-- Справочники — первыми: на них ссылаются остальные таблицы.
create table data_type (
    id       int  generated always as identity primary key,
    name     text not null unique,   -- 'wind_speed', 'power', ...
    measure  text not null           -- единица измерения: 'm/s', 'kW', ...
);
comment on table data_type is 'Справочник типов измеряемых величин';

create table event_type (
    id           int  generated always as identity primary key,
    name         text not null unique,
    category     text not null,      -- группа событий: 'alarm', 'warning', 'info', ...
    description  text
);
comment on table event_type is 'Справочник типов событий из журнала событий';

-- Основные сущности.
create table wind_farm (
    id       int  generated always as identity primary key,
    code     text not null unique,   -- 'KELMARSH'
    name     text not null,
    country  text not null,
    region   text not null
);
comment on table wind_farm is 'Ветропарк, на котором стоят турбины';

create table turbine (
    id            int     generated always as identity primary key,
    farm_id       int     not null references wind_farm(id),
    turbine_type  text    not null,  -- модель турбины: 'Senvion MM92'
    power         numeric not null check (power > 0),  -- номинальная мощность, кВт
    mass          numeric not null check (mass > 0)    -- масса, т
);
comment on table turbine is 'Ветряная турбина конкретного ветропарка';

create table sensor (
    id           int  generated always as identity primary key,
    turbine_id   int  not null references turbine(id),
    sensor_type  text not null,      -- вид датчика
    description  text
);
comment on table sensor is 'Датчик, установленный на турбине';

create table part (
    id               int  generated always as identity primary key,
    article_number   text not null unique,
    turbine_id       int  not null references turbine(id),
    name             text not null,
    unit_of_measure  text not null   -- 'шт', 'л', 'кг', ...
);
comment on table part is 'Запчасть, относящаяся к конкретной турбине';

-- Данные, которые меняются во времени.
create table event (
    id             int         generated always as identity primary key,
    sensor_id      int         not null references sensor(id),
    event_type_id  int         not null references event_type(id),
    start_time     timestamptz not null,
    duration       interval    not null check (duration >= interval '0'),
    message        text
);
comment on table event is 'Событие из журнала событий, связанное с датчиком';

create table telemetry (
    ts            timestamptz not null,
    sensor_id     int         not null references sensor(id),
    data_type_id  int         not null references data_type(id),
    value         numeric     not null,
    unit          text        not null,
    -- Один датчик не может дать два значения одной величины в один момент.
    primary key (sensor_id, data_type_id, ts)
);
comment on table telemetry is 'Показания датчиков за время работы турбины';

-- Тестовые данные — чтобы схему можно было «пощупать».
insert into wind_farm (code, name, country, region)
values ('KELMARSH', 'Kelmarsh', 'UK', 'Northamptonshire');

insert into turbine (farm_id, turbine_type, power, mass)
values (1, 'Senvion MM92', 2050, 230);

insert into sensor (turbine_id, sensor_type, description)
values (1, 'anemometer', 'Датчик скорости ветра на гондоле'),
       (1, 'power_meter', 'Датчик активной мощности');

insert into data_type (name, measure)
values ('wind_speed', 'm/s'),
       ('power', 'kW');

insert into event_type (name, category, description)
values ('overspeed', 'alarm', 'Превышена допустимая скорость вращения');

insert into event (sensor_id, event_type_id, start_time, duration, message)
values (1, 1, '2026-01-10 12:00+00', interval '5 minutes', 'Порыв ветра выше порога');

insert into part (article_number, turbine_id, name, unit_of_measure)
values ('GB-0001', 1, 'Масляный фильтр редуктора', 'шт');

insert into telemetry (ts, sensor_id, data_type_id, value, unit)
values ('2026-01-10 12:00+00', 1, 1, 12.4, 'm/s'),
       ('2026-01-10 12:00+00', 2, 2, 1850, 'kW'),
       ('2026-01-10 12:10+00', 1, 1, 11.8, 'm/s');
