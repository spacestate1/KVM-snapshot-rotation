# Copyright (c) 2020 CWM.
#
# This program is free software: you can redistribute it and/or modify  
# it under the terms of the GNU General Public License as published by  
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License 
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#


#### NOTICE: Snapshots are not a true VM backup! This is intended to preserve configuration changes only.

#!/bin/bash

printf -v DATE '%(%Y-%m-%d)T' -1
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
			   /usr/bin/virsh snapshot-delete --domain $vm02 --snapshotname $snaps
#### Create a new snapshot if one has not been made for one week
		   elif [ "$weeks_time" -eq 1 ]; then

			  new_snap="_${DATE}_autosnapped"

			  if [[ ! " ${prev_snaps[@]} " =~ "${new_snap}" ]]; then
		               echo "Creating new snapshot ${new_snap} on ${vm02}"
			       /usr/bin/virsh snapshot-create-as --domain $vm02 --name $new_snap

			  else
				  echo "Snapshot ${new_snap} on ${vm02} already exists"
				  echo $snaps $snap_time
			  fi
#### echo output if weekly snapshot is in place
	          else

			  echo "VM:$vm02,autosnapshot:$snaps,weeks_old:$weeks_time"
		  fi
                done
          fi
          done
else
    echo "No snapshots found on any running VMs"
 fi
done

#### Make an initial snapshot if it doesn't exist

for vm02 in $(echo $vm01)
do
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
       if [[ "${init_snaps[@]}" == *"_init_autosnapped"* ]];
           then
               echo "existing init snaps found on ${vm02}"
               :
           else
               first_snap="_init_autosnapped"
               echo "Creating first snapshot ${first_snap} on ${vm02}"
               /usr/bin/virsh snapshot-create-as --domain $vm02 --name $first_snap
       fi
done
