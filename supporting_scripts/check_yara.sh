#!/bin/bash
function dir_check()
{

if [ ! -d $1 ]; then
	echo "$1 does not exist. Creating.."
	mkdir -p $1
else
	echo "$1 already exists. (No problem, We'll use it anyhow)"
fi

}

dir_check /home/cuckoo/.cuckoo/yara/test/
dir_check /home/cuckoo/.cuckoo/yara/test/allrules
dir_check /home/cuckoo/Desktop/yararesults
dir_check /home/cuckoo/Desktop/yararesults/

rules_path=/home/cuckoo/.cuckoo/yara/test/
out_dir=/home/cuckoo/Desktop/yararesults/

cd $rules_path
#git clone https://github.com/yara-rules/rules.git 

for y in $(ls -d $rules_path/rules/*/)
do
  ls -d $y/*.yar > $rules_path/index.txt
done

cp $rules_path/rules/**/*.yar $rules_path/allrules/
ls $rules_path/allrules/ > $rules_path/rules.txt

mkfifo /tmp/pipe
counter=0

for x in $(cat $rules_path/rules.txt)
do
  if [ $counter -lt 2 ]; then # we are under the limit
    { vol.py -f /home/cuckoo/.cuckoo/storage/analyses/12/memory.dmp --profile=Win7SP1x64 yarascan --yara-file=$rules_path/allrules/$x --output=text --output-file=$out_dir/$x.log > /tmp/pipe; } &
    let $[counter++];
  else
    read x < tmp
    { vol.py -f /home/cuckoo/.cuckoo/storage/analyses/12/memory.dmp --profile=Win7SP1x64 yarascan --yara-file=$rules_path/allrules/$x --output=text --output-file=$out_dir/$x.log > /tmp/pipe; } &
   fi
done
cat $pipe > /dev/null # let all the background processes end
rm /tmp/pipe # remove fifo










#for x in $(cat $rules_path/index.txt)
#do
#  vol.py -f /home/cuckoo/.cuckoo/storage/analyses/12/memory.dmp --profile=Win7SP1x64 yarascan --yara-file=$x
#done


#for x in $(cat $rules_path/rules.txt)
#do
#     while [`jobs | wc -l` -ge 20]
#     do
#     sleep 1
#     done
#     touch $out_dir/$x.log
#     xterm -hold -e vol.py -f /home/cuckoo/.cuckoo/storage/analyses/12/memory.dmp --profile=Win7SP1x64 yarascan --yara-file=$rules_path/allrules/$x  &
#done
