
# Troubleshooting log

Real problems I hit while building this project, and how I fixed them.

## Phase 1: EC2 + EBS

### 1. `curl: (26) Failed to open/read local data`

- **Symptom:** Upload with `curl -F "file=@test.txt"` failed immediately.
- **Cause:** `test.txt` did not exist in the current directory.
- **Fix:** Created the file and checked with `ls` and `pwd`.
- **Lesson:** `@file` is read from the current directory.

### 2. `zsh: parse error near newline`

- **Symptom:** `ssh ... ec2-user@<PUBLIC_IP>` failed before running.
- **Cause:** I pasted the placeholder literally. `<` and `>` are shell redirection operators.
- **Fix:** Replaced the placeholder with the real IP.
- **Lesson:** Anything in `< >` in docs is a value to replace.

### 3. `/data` not mounted after reboot (`mount -a: parse error at line 4`)

- **Symptom:** After reboot, `df -h /data` showed the root disk (`nvme0n1p1`, 8G) instead of the EBS volume.
- **Cause:** I pasted the full `blkid` output into `/etc/fstab` (extra `BLOCK_SIZE` and `TYPE` fields) and appended the line twice.
- **Fix:** Removed the bad lines with `sed -i '/\/data/d' /etc/fstab` and added one 6-field line.
- **Lesson:** Always run `mount -a` and check `df` before rebooting. `nofail` kept the instance bootable.

### 4. File written to the wrong disk, silently

- **Symptom:** `hello.txt` existed in `/data`, but `df` showed the root disk.
- **Cause:** I wrote the file while `/data` was not mounted, so it landed on the root volume.
- **Fix:** Deleted it before mounting the volume over the directory.
- **Lesson:** An unmounted mount point is just a normal directory. Writes succeed and go to the wrong disk.

### 5. `502 Bad Gateway` from Nginx

- **Symptom:** `curl http://<IP>/health` returned 502.
- **Cause:** The systemd unit file was never written, so nothing listened on `127.0.0.1:8000`.
- **Fix:** Created `storage-lab.service` and enabled it.
- **Lesson:** 502 means Nginx is up but the upstream is not. Check `systemctl status`, `journalctl`, then `ss -ltnp`.

### 6. `uvicorn: command not found`

- **Symptom:** Running the app manually in a new SSH session failed.
- **Cause:** The virtualenv was not activated in that session.
- **Fix:** The systemd unit uses the full path `.venv/bin/uvicorn`.
- **Lesson:** systemd does not activate a venv or use my shell's `PATH`.

### 7. Upload "worked" but nothing was uploaded

- **Symptom:** `curl -s -F "file=@test.txt" ...` printed nothing.
- **Cause:** I created `text.txt` instead of `test.txt`, and `-s` hid the error (exit code 26).
- **Fix:** Created the right file and dropped `-s`.
- **Lesson:** A command that should print something and prints nothing has probably failed.

### 8. `Connection refused` right after reboot

- **Symptom:** First `curl` / `ssh` after reboot failed, the second worked.
- **Cause:** The instance was still booting.
- **Lesson:** `refused` = reached the host, nothing listening yet. `timed out` = never reached it (Security Group or my IP changed).

### 9. `argument --volume-id: expected one argument`

- **Symptom:** `attach-volume --volume-id $ENC_VOL` failed.
- **Cause:** `$ENC_VOL` was empty, because the `create-volume` step had not run.
- **Fix:** Checked state with `describe-snapshots` / `describe-volumes` filtered by tag, then ran the missing step.
- **Lesson:** `echo` variables before using them. Tags make it easy to find where a process stopped.

### 10. `zsh: command not found: --instance-id`

- **Symptom:** A multi-line command ran as two commands.
- **Cause:** The first line was missing the trailing `\`.
- **Lesson:** `\` continues a command on the next line. When unsure, use one line.

### 11. `UnauthorizedOperation` from inside the instance (expected)

- **Symptom:** `aws ec2 describe-volumes-modifications` on the EC2 instance was denied.
- **Cause:** The instance role has a trust policy but no permission policy.
- **Lesson:** This is least privilege working. The instance can prove its identity (`sts` works) but cannot touch my infrastructure. Infra commands run from my machine.
