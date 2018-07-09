#!/bin/bash
PSI="../../../psi"
BAYONET="../../../bayonet"

git clone https://github.com/eth-sri/psi.git $PSI
git clone https://github.com/eth-sri/bayonet.git $BAYONET
(cd $PSI && ./dependencies.sh && ./build.sh)
(cd $BAYONET && ./dependencies.sh && ./build.sh)
