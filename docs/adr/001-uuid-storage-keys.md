constransts


## Constraints

| Column            | Rule                                   | Why                                                              |
| ----------------- | -------------------------------------- | ---------------------------------------------------------------- |
| `storage_key`   | `UNIQUE`, not empty                  | Each row points to exactly one stored file                       |
| `original_name` | `NOT NULL`                           | Needed to return the file with its real name on download         |
| `size_bytes`    | `>= 0`                               | An empty file is valid; a negative size means corrupted metadata |
| `status`        | `pending`, `stored`, or `failed` | The app only handles these states; anything else is a bug        |
