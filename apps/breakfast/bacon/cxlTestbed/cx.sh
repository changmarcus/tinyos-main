#!/bin/bash
function runTestbed(){
  testDuration=$((60 * 60))
  installTS=$(date +%s)
  for i in $(seq 1)
  do
    ./testbed.sh installTS $installTS $@
    sleep 60
  done
  sleep $testDuration
  pushd .
  cd ~/tinyos-2.x/apps/Blink
  ./burn map.all
  sleep 60
  popd
}

#- start with these 5, do an hour of each
while true
do

  # 2 multitier+params: map is map.patches.8. data rate is ~daily download
  #    - 44 B per sample, 144 per day = 6336 B, round it up to an even
  #      75 ppd with pl=100 to be safe (4B cookie per record -> 6912,
  #      and each packet would have next cookie, len, etc)
  #   idle
  #     vary slot length
  #   active: ppd=75 mdr=100, fps=60, tpl=100
  #     vary slot length

  #vary slot length
  mdr=100
  tpl=100
  for ppd in 75 0
  do
    for fps in 60 40 80 
    do
      runTestbed map maps/segmented/map.patches.9 efs 1 ppd $ppd mdr $mdr tpl $tpl fps $fps tdel 184320UL ts 2 sdel 122880UL
    done
  done
  
  #vary "download interval"
  for ppd in 25 50 150
  do
    for fps in 60
    do
      runTestbed map maps/segmented/map.patches.9 efs 1 ppd $ppd mdr $mdr tpl $tpl fps $fps tdel 368640UL ts 2 sdel 122880UL
    done
  done
  

  # 3 validation: 60 fps
  fps=60
  tpl=12
  mdr=1
  #   idle: 0 ppd
  runTestbed map maps/flat/map.flat.0 efs 0 ppd 0 mdr $mdr tpl $tpl fps $fps td 0
  #   active: 50 ppd, mdr=1, pl=12 (ppd doesn't really matter, we only do one round)
  #     fsel on
  #     fsel off
  for efs in 0 1
  do
    runTestbed map maps/flat/map.flat.0 efs $efs ppd 50 mdr $mdr tpl $tpl fps $fps td 0
  done

done

#wakeup? OK to leave as sim until the rest of the data is in and cool
#  probe interval
#  compute wakeup length
#  log idle dc
