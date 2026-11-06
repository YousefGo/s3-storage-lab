# ADR-002: Store app data on a separate EBS volume

**Status:** Accepted

**Context:**
The app stores uploaded files and a SQLite database on local disk.
If they live on the root volume, they are mixed with the OS and the code,
and they are deleted when the instance is terminated.

**Decision:**
Store all app data on a separate gp3 EBS volume mounted at `/data`.
The app finds it through the `DATA_DIR` environment variable.

**Why:**
- The data volume survives instance termination (`DeleteOnTermination = false`).
- Snapshots back up only the data, not the OS. I restored it in another AZ and copied it to another region.
- I can resize and encrypt the data volume without touching the OS.
- The code is rebuilt from Git; only the data needs protecting.

**Rejected alternatives:**
- Root volume: deleted on termination, and data is mixed with the OS.
- Instance Store: data is lost on stop/start, so not acceptable for user files.
- S3 (for now): the app writes to local file paths; moving to S3 is Phase 2.

**Trade-offs:**
- More to manage: I format, mount and configure `fstab` myself. A bad `fstab` line left `/data` unmounted after reboot (see troubleshooting #3).
- The volume is locked to one AZ, and only one instance can use it. Sharing files across instances needs EFS (Phase 6).