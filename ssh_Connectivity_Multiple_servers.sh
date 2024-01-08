#!/bin/bash
#
# Testing SSH Connectivity to Multiple Servers
#hostlist= is the path of the host file
configure() {
  hostlist="/var/adm/bin/server_list_primary.txt"
  hostlist_resolved="${hostlist}_resolved"
  hostlist_processed="${hostlist}_processed"
  username="set the username"
  safeword="set the password"

  if [ ! -f "${hostlist}" ]
  then
    echo "Host list file $hostlist not found. Exiting..." ; exit 1
  fi

  if [ -f "${hostlist_resolved}" ]
  then
    /bin/rm "${hostlist_resolved}"
  fi

  if [ -f "${hostlist_processed}" ]
  then
    /bin/rm "${hostlist_processed}"
  fi
}

resolve() {
  cat "${hostlist}" | while read line
  do
    if [ `/usr/bin/host ${line} | grep -c "not found"` -eq 0 ]
    then
      /usr/bin/host ${line} | tail -1 | while read line2
      do
        fqdn=$(echo ${line2} | awk '{print $1}')
        ip=$(echo ${line2} | awk '{print $NF}')
        echo "${line},resolved,${fqdn},${ip}" >> "${hostlist_resolved}"
        echo "${line},resolved,${fqdn},${ip}"
      done
    else
      echo "${line},unresolved" >> "${hostlist_resolved}"
      echo "${line},unresolved"
    fi
  done
}

check_safeword() {
  cat "${hostlist_resolved}" | while read line
  do
    if [ `echo $line | grep -c ",unresolved"` -eq 0 ]
    then
      status=2
      host=$(echo $line | awk -F',' '{print $1}')
      status=$(echo "" | ssh -n -q -T -o "BatchMode=yes" ${safeword}@$host echo 2>&1 | grep -ic "safeword" | tail -1)
      if [ ${status} -eq 1 ]
      then
        echo "${line},safeword" >> "${hostlist_processed}"
        echo "${line},safeword"
      else
        echo "${line},notsafeword" >> "${hostlist_processed}"
        echo "${line},notsafeword"
      fi
    else
      echo "${line}" >> "${hostlist_processed}"
    fi
    sleep 1
  done

  /bin/mv "${hostlist_processed}" "${hostlist_resolved}"
}

check_passwordless() {
  cat "${hostlist_resolved}" | while read line
  do
    if [ `echo $line | grep -c ",unresolved"` -eq 0 ]
    then
      if [ `echo $line | grep -c ",safeword"` -eq 0 ]
      then
        status=2
        host=$(echo $line | awk -F',' '{print $1}')
        status=$(ssh -n -T -o "BatchMode=yes" ${username}@$host echo 2>&1 | grep -c denied)
        if [ ${status} -eq 1 ]
        then
          echo "${line},password_requried" >> "${hostlist_processed}"
          echo "${line},password_requried"
        else
          echo "${line},passwordless" >> "${hostlist_processed}"
          echo "${line},passwordless"
        fi
      else
        echo "${line},password_requried" >> "${hostlist_processed}"
      fi
    else
      echo "${line}" >> "${hostlist_processed}"
    fi
    sleep 1
  done

  /bin/mv "${hostlist_processed}" "${hostlist_resolved}"
}

try_password() {
  touch "${hostlist_processed}"
  chmod 600 "${hostlist_processed}"
  cat "${hostlist_resolved}" | while read line
  do
    if [ `echo $line | grep -c ",unresolved"` -eq 0 ]
    then
      if [ `echo $line | grep -c ",safeword"` -eq 0 ]
      then
        if [ `echo $line | grep -c ",passwordless"` -eq 0 ]
        then
          status=1
          host=$(echo $line | awk -F',' '{print $1}')
          for password in 'password1' 'password2' 'password3'
          do
            status=$(expect -c "
            set timeout 5
            spawn ssh ${username}@$host "hostname"
            expect "password:" { send "${password}r" }
            expect eof " | tail -1 | grep -c "ssword")
            if [ $status -eq 0 ]
            then
              echo "${line},${password}" >> "${hostlist_processed}"
              echo "${line},${password}"
              break
            fi
          done
          if [ $status -ne 0 ]
          then
            echo "${line},nopass" >> "${hostlist_processed}"
            echo "${line},nopass"
          fi
          sleep 1
        else
          echo "${line}" >> "${hostlist_processed}"
        fi
      else
        echo "${line}" >> "${hostlist_processed}"
      fi
    else
      echo "${line}" >> "${hostlist_processed}"
    fi
  done
}

configure
resolve
check_safeword
check_passwordless
try_password

echo "Check ${hostlist_processed} for status"
