create table if not exists files (
id integer primary key autoincrement,
storage_key varchar(255) not null unique,
original_name varchar(255) not null,
content_type varchar(255),
size_bytes integer not null,
status varchar(20) not null check (status in ('pending', 'stored', 'failed')),
created_at timestamp not null default current_timestamp
);
