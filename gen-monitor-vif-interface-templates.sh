#!/bin/bash
#monitor interfaces [type] [name] traffic
#monitor interfaces [type] [name] traffic save [filename]
#monitor interfaces [type] [name] traffic detail
#monitor interfaces [type] [name] traffic detail filter
#monitor interfaces [type] [name] traffic detail unlimited
#monitor interfaces [type] [name] traffic detail unlimited filter
#monitor interfaces [type] [name] traffic filter
#monitor interfaces [type] [name] traffic unlimited
#monitor interfaces [type] [name] traffic unlimited filter

declare -a types=(
       "ethernet" \
       "bonding" \
)

for type in "${types[@]}"; do
  mkdir -p $type/node.tag/vif/node.tag/traffic/save/node.tag
  mkdir -p $type/node.tag/vif/node.tag/traffic/detail/filter/node.tag
  mkdir -p $type/node.tag/vif/node.tag/traffic/detail/unlimited/filter/node.tag
  mkdir -p $type/node.tag/vif/node.tag/traffic/filter/node.tag
  mkdir -p $type/node.tag/vif/node.tag/traffic/unlimited/filter/node.tag
  
  #node.tag
  echo "help: Monitor specified $type interface" > $type/node.tag/vif/node.tag/node.def
  echo "allowed: \${vyatta_sbindir}/vyatta-interfaces.pl --show $type --vif \${COMP_WORDS[COMP_CWORD-2]}" >> $type/node.tag/vif/node.tag/node.def
  echo "run: \${vyatta_bindir}/vyatta-show-interfaces.pl --intf=\"$4.$6\"" >> $type/node.tag/vif/node.tag/node.def

  # standard
  echo "help: Montior captured traffic on specified $type interface" > $type/node.tag/vif/node.tag/traffic/node.def
  echo 'run: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6' >> $type/node.tag/vif/node.tag/traffic/node.def

  # save
  echo 'help: Save monitored traffic to a file' >  $type/node.tag/vif/node.tag/traffic/save/node.def
  echo -e 'help: Save monitored traffic to a file\nrun: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6 --save "${@:9}"' >  $type/node.tag/vif/node.tag/traffic/save/node.tag/node.def

  # detail
  echo -e "help: Monitor detailed traffic for the specified $type interface"> $type/node.tag/vif/node.tag/traffic/detail/node.def

  echo -e 'run: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6 --detail' >> $type/node.tag/vif/node.tag/traffic/detail/node.def

  # detail filter
  echo "help: Monitor detailed filtered traffic for the specified $type interface" >  $type/node.tag/vif/node.tag/traffic/detail/filter/node.def
  echo -e "help: Monitor detailed filtered traffic for the specified $type interface" > $type/node.tag/vif/node.tag/traffic/detail/filter/node.tag/node.def
  echo 'run: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6 --detail --filter "${@:10}"' >> $type/node.tag/vif/node.tag/traffic/detail/filter/node.tag/node.def

  # detail unlimited
  echo -e "help: Monitor detailed traffic for the specified $type interface" > $type/node.tag/vif/node.tag/traffic/detail/unlimited/node.def
  echo 'run: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6 --detail --unlimited' >> $type/node.tag/vif/node.tag/traffic/detail/unlimited/node.def

  # detail unlimited filter
  echo "help: Monitor detailed filtered traffic for the specified $type interface" >  $type/node.tag/vif/node.tag/traffic/detail/unlimited/filter/node.def
  echo "help: Monitor detailed filtered traffic for the specified $type interface" > $type/node.tag/vif/node.tag/traffic/detail/unlimited/filter/node.tag/node.def
  echo 'run: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6 --detail --unlimited --filter "${@:11}"' >> $type/node.tag/vif/node.tag/traffic/detail/unlimited/filter/node.tag/node.def

  #filter
  echo "help: Monitor filtered traffic for the specified $type interface" > $type/node.tag/vif/node.tag/traffic/filter/node.def
  echo "help: Monitor filtered traffic for the specified $type interface" > $type/node.tag/vif/node.tag/traffic/filter/node.tag/node.def
  echo 'run: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6 --filter "${@:9}"' >> $type/node.tag/vif/node.tag/traffic/filter/node.tag/node.def

  # unlimited
  echo "help: Monitor traffic for the specified $type interface" > $type/node.tag/vif/node.tag/traffic/unlimited/node.def
  echo 'run: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6 --unlimited' >> $type/node.tag/vif/node.tag/traffic/unlimited/node.def

  # unlimited filter
  echo "help: Monitor filtered traffic for the specified $type interface" >  $type/node.tag/vif/node.tag/traffic/unlimited/filter/node.def
  echo "help: Monitor filtered traffic for the specified $type interface" > $type/node.tag/vif/node.tag/traffic/unlimited/filter/node.tag/node.def
  echo 'run: ${vyatta_bindir}/vyatta-tshark.pl --intf $4.$6 --unlimited --filter "${@:10}"' >> $type/node.tag/vif/node.tag/traffic/unlimited/filter/node.tag/node.def

done
