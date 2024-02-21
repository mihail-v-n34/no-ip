## no-ip.sh

This script keeps your No-IP dynamic DNS record up to date while interpreting the response code as required[^1].

### Usage

Just edit these three variables in the script:
```bash
root@host:~# head -n 6 no-ip.sh
#!/bin/bash

hostname="your-hostname"
login="your-login"
password="your-password"
```
And add it to crontab:
```bash
root@host:~# crontab -l | grep no-ip.sh
0 */2 * * * /root/no-ip.sh
```

### Tips

<details>
  <summary>How to keep a log</summary>
  
  If you would like to keep a log, it could be done with something like this:
  ```bash
  root@host:~# touch /var/log/no-ip.log
  root@host:~# chown syslog:adm /var/log/no-ip.log
  root@host:~# chmod 640 /var/log/no-ip.log
  root@host:~# crontab -l | grep no-ip.sh
  0 */2 * * * /root/no-ip.sh >> /var/log/no-ip.log 2>&1
  ```
  Don't forget to rotate that log file:
  ```bash
  root@host:~# cat /etc/logrotate.d/no-ip
  /var/log/no-ip.log
  {
  	rotate 4
  	weekly
  	missingok
  	notifempty
  	compress
  	delaycompress
  	postrotate
  		invoke-rc.d rsyslog reload > /dev/null
  	endscript
  }
  ```
</details>

<details>
  <summary>How to set up notifications</summary>

  If you use some other script that sends you notifications, you can modify your crontab entry to something like this:
  ```bash
  0 */2 * * * /root/notify.sh "$(/root/no-ip.sh)" >/dev/null 2>&1
  ```

  And this will notify you only when the DNS record gets updated:
  ```bash
  0 */2 * * * noIpLog="$(/root/no-ip.sh)"; [ ! -z "$(printf "$noIpLog" | grep updated)" ] && /root/notify.sh "$(printf "$noIpLog")"
  ```
</details>

[^1]: https://www.noip.com/integrate/request