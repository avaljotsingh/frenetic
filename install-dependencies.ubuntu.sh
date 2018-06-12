#!/bin/bash
sudo apt-get update
sudo apt-get install libsuitesparse-dev python3-pip libcurl4-openssl-dev graphviz
sudo -H python3 -m pip install --upgrade pip
sudo -H python3 -m pip install \
  $(pip3 list --outdated --format=legacy | awk '{ print $1 }') --upgrade
python3 -m pip install --user --upgrade \
  numpy scipy matplotlib ipython jupyter pandas sympy nose scikit-umfpack bson