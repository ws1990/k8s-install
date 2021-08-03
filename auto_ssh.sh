#!/usr/bin/expect  
set timeout 10  
set username [lindex $argv 0]  
set password [lindex $argv 1]  
set hostname [lindex $argv 2]

# 生成密钥
spawn ssh-keygen
expect {
"Enter file in which to save the key (/root/.ssh/id_rsa):" { send "\r"; exp_continue}
"Enter passphrase (empty for no passphrase):" { send "\r"; exp_continue} 
"Enter same passphrase again:" { send "\r"; exp_continue}
}

# 免密登录其他服务器
spawn ssh-copy-id -i /root/.ssh/id_rsa.pub $username@$hostname
expect {
            #first connect, no public key in ~/.ssh/known_hosts
            "Are you sure you want to continue connecting (yes/no)?" {
            send "yes\r"
            expect "password:"
                send "$password\r"
            }
            #already has public key in ~/.ssh/known_hosts
            "password:" {
                send "$password\r"
            }
            "Now try logging into the machine" {
                #it has authorized, do nothing!
            }
        }
expect eof
