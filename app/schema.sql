create table if not exists files (
id integer primary key autoincrement,
storage_key vrchar(255) not null unique check (storage_key <> ''),
original_name varchar(255) not null,
content_type varchar(255),
size_bytes integer not null check (size_bytes >= 0),
status varchar(20) not null check (status in ('pending', 'stored', 'failed')),
created_at timestamp not null default current_timestamp
);
