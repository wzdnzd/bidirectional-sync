## Bi-Directional-Sync

> Note: 
> * requires rsync >= 3.1 on all source and target machines

Real-time bi-directional synchronization tools between two data centers base on [lsyncd](https://github.com/axkibe/lsyncd). The sync direction control by DNS and master to slave.

### Install Packages
- [lsyncd](https://centos.pkgs.org/7/epel-x86_64/lsyncd-2.2.2-1.el7.x86_64.rpm.html)
- [lua-socket](https://centos.pkgs.org/7/epel-x86_64/lua-socket-3.0-0.17.rc1.el7.x86_64.rpm.html)
```bash
yum install -y rsync

rpm -ivh https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/l/lsyncd-2.2.2-1.el7.x86_64.rpm
rpm -ivh https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/l/lua-socket-3.0-0.17.rc1.el7.x86_64.rpm 
```

### Clone and Config
> Note: Use dos2unix reformat all files
```bash
vim /etc/lsyncd/config.json
```
> Params:
> * host: target server 
> * delete: whether to allow deletion when synchronizing
> * script: the path of shell script
> * excludeFrom: list of files that need to be excluded
> * port: ssh port
> * bwlimit: bandwidth limit
> * ...

### Access without Requiring a Password
```bash
ssh-keygen -t rsa
ssh-copy-id root@target
```

### Execute Lsyncd
+ start with utils/lsyncd-cli.sh
```bash
./utils/lsyncd-cli.sh start
```
+ start with systemctl
```bash
# modify 'LSYNCD_OPTIONS' point to the conf/bisync.conf.lua 
vim /etc/sysconfig/lsyncd

# enable auto startup when boosting
systemctl enable lsyncd

# start
systemctl start lsyncd
```

### Reference
+ [lsyncd实时同步搭建指南](http://seanlook.com/2015/05/06/lsyncd-synchronize-realtime/)
+ [lsyncd](http://axkibe.github.io/lsyncd/)