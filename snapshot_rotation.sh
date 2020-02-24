#!/bin/bash
#### NOTICE: Snapshots are not a true VM backup! This is intended to preserve configuration changes only.
#### Tested on KVM v4

printf -v DATE '%(%Y-%m-%d)T' -1
printf -v week_DATE '%(%Y-%U)T' -1
e_date=$(date -d $DATE +"%s")

#### List running VMs
vm01="$(/usr/bin/virsh list --state-running | tail -n +2 | awk -F " " '{print $2}' | sed '/^$/d' | tr " " "\n")"

#### List previous snapshots and parse out creation time
for vm02 in $(echo $vm01)
do
    if [[ $(/usr/bin/virsh snapshot-list $vm02) ]]; then
        name="$(/usr/bin/virsh snapshot-list $vm02 | tail -n +3| awk -F ' ' '{print $1}' | sed '/^$/d')"
        h=0

#### Make array to check existing snapshots for autosnapshots
       for isnap1 in $(echo $name)
           do
           prev_snaps[$h]=$isnap1
           ((h++))
           done
            for snaps in $(echo $name)
            do
            if [[ $snaps == _* ]];
            then
                   time="$(/usr/bin/virsh snapshot-list $vm02 | tail -n +3 | grep $snaps | awk -F ' ' '{print $2}' | sed '/^$/d')"

#### Get dates and times of existing autosnaps for snapshot creation
               for snap_time in $(echo $time)
               do
                   e_snap_time=$(date -d $snap_time +"%s")
                   time_diff="$((e_date - e_snap_time))"
                   weeks_time="$((time_diff / 604800))"

                   if [ "$weeks_time" -gt 52 ]; then
                           echo "${e_snap_time} Removing 52 week old snapshot ${weeks_time}" >> remove.log
                           /usr/bin/virsh snapshot-delete --domain $vm02 --snapshotname $snaps
#### Create a new snapshot if one has not been made for one week
                   elif [ "$weeks_time" -ge 1 ]; then

                          new_snap="_${week_DATE}_autosnapped"

                          if [[ ! " ${prev_snaps[@]} " =~ "${new_snap}" ]]; then
                               echo "Creating new snapshot ${new_snap} on ${vm02}" >> new_snap_log.log
                               /usr/bin/virsh snapshot-create-as --domain $vm02 --name $new_snap

                          else

                                  echo "Snapshot ${new_snap} on ${vm02} already exists"
                                  echo $snaps $snap_time
                          fi
                  fi
                done
          fi
          done
else
    echo "No snapshots found on any running VMs"
 fi

done

#### Make an initial snapshot if it doesn't exist

#### Function to check existing snapshots ####
init_check () {
      local init_snaps1="$1[@]"
      local seeking="_init_autosnapped"
      local in=1
      for snap01 in "${!init_snaps1}"; do
        if [[ $snap01 == "$seeking" ]]; then
            in=0
            break
        fi
    done
    return $in
    }

for vm02 in $(echo $vm01)
do
	init_snaps=()

if [[ $(/usr/bin/virsh snapshot-list $vm02) ]]; then

        name="$(/usr/bin/virsh snapshot-list $vm02 | tail -n +3| awk -F ' ' '{print $1}' | sed '/^$/d')"
fi
       i=0

#### Create array to check existing snapshots for init autosnapshots
       for isnap in $(echo $name)
       do
       init_snaps[$i]=$isnap
       ((i++))
       done
       init_check init_snaps && result="1" || result="0"
       if [[ ${result} -eq "1" ]];
           then
               echo "existing init snaps found on ${vm02} ${name}"

       elif [[ ${result} -eq "0" ]];
       then
               first_snap="_init_autosnapped"
               /usr/bin/virsh snapshot-create-as --domain $vm02 --name $first_snap
       fi
done
