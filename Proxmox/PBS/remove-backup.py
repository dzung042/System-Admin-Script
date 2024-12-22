# this script will remove backup not backup days_before, because proxbackup not auto remove VM if VM was deteled
from datetime import date, timedelta, datetime
from proxmoxer import ProxmoxAPI


# variable
days_before = (date.today()-timedelta(days=90)).isoformat()
print("Remove backup before: ",days_before)
days_before1 = datetime.strptime(days_before,"%Y-%m-%d")
days_remove = days_before1.strftime('%s')
print(days_remove)
## Host info
pbs_host = "192.16.1.20:8007"
## API info
pbs_user = "root@pam"
pbs_password = "1231234"

proxmox = ProxmoxAPI(
    pbs_host, user=pbs_user, password=pbs_password, verify_ssl=False, service='pbs'
)
new_list = []
for pbs_backup in proxmox("admin/datastore/BackupPR/groups").get():
     if pbs_backup['last-backup'] < int(days_remove):
        print("Remove backup: VM {0}: Last: {1}".format(pbs_backup['backup-id'], date.fromtimestamp(pbs_backup['last-backup'])))
        proxmox("admin/datastore/BackupPR/groups?backup-type=vm&backup-id={0}".format(pbs_backup['backup-id'])).delete()
