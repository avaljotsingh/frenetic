#!/usr/bin/env python3
import matplotlib
matplotlib.use('Agg')

import matplotlib.pyplot as plt
import numpy as np
import os
import re
import sys
from collections import defaultdict
from glob import glob
from prettytable import PrettyTable


DATA_DIR = "."

matplotlib.rcParams['pdf.fonttype'] = 42
matplotlib.rcParams['ps.fonttype'] = 42

# results will be sorted lexiographically by their parameters
PARAMS = [
  'scheme',
  'k',
  'prism',
  'cps',
  'dont_iterate',
  'parallelize',
]

methods = [
  'bayonet',
  'probnetkat_false_true_24',
  'probnetkat_false_true_0',
  'prism_exact',
  'prism_approx',
  'prism_exact.compiled',
  'prism_approx.compiled',
]

label_of_method = {
  'bayonet' : 'Bayonet',
  'probnetkat_false_true_24' : 'ProbNetKAT (cluster)',
  'probnetkat_false_true_0' : 'ProbNetKAT',
  'prism_exact' : 'Prism (exact)',
  'prism_approx' : 'Prism (approx)',
  'prism_exact.compiled' : 'PPNK (exact)',
  'prism_approx.compiled' : 'PPNK (approx)',
}

markers = {
  'bayonet' : 'o',
  'probnetkat_false_true_24' : 's',
  'probnetkat_false_true_0' : '*',
  'prism_exact': 'X',
  'prism_approx' : 'D',
  'prism_exact.compiled' : 'o',
  'prism_approx.compiled' : 'x',
}

colors = {
  'bayonet' : 'darkgreen',
  'probnetkat_false_true_24' : 'navy',
  'probnetkat_false_true_0' : 'orange',
  'prism_exact' : 'red',
  'prism_approx' : 'purple',
  'prism_exact.compiled' : 'green',
  'prism_approx.compiled' : 'black',
}

def parse_output(folder):
  results = []
  for file in glob(os.path.join(folder, '*.log')):
    print(file)
    result = dict()
    
    # parse parameters
    for param in PARAMS:
      match = re.search(r'%s=(?:(?P<n>\d+)|(?P<s>[a-zA-Z]+))' % param, file)
      if match is None:
        raise Exception("Could not parse file name: %s" % file)
      match = match.groupdict()
      if match['n'] is not None:
        result[param] = int(match['n'])
      else:
        result[param] = match['s']
    
    # parse result
    with open(file) as f:
      log = '\n'.join(f.readlines()[::-1])
      time = r'TIME: (?P<time>\d+(\.\d*))\.'
      timeout = r'TIMEOUT: (?P<timeout>\d+) seconds\.'
      error = r'ERROR: (?P<error>\d+)\.'
      match = re.search(r'(:?%s)|(:?%s)|(:?%s)' % (time, timeout, error), log)
      if match is None:
        raise Exception("Could not parse result in %s" % file)
      outcome = match.groupdict()
      if outcome['time'] is not None:
        result['time'] = float(outcome['time'])
      elif outcome['timeout'] is not None:
        result['timeout'] = float(outcome['timeout'])
      elif outcome['error'] is not None:
        result['error'] = int(outcome['error'])
      else:
        assert False
    # add to results
    print(result)
    results.append(result)
  return results


def dump(data):
  t = PrettyTable()
  cols = PARAMS + ['RESULT']
  t.field_names = [c for c in cols]
  for point in data:
    row = [point[p] for p in PARAMS]
    if 'time' in point:
      row.append(point['time'])
    elif 'timeout' in point:
      row.append('TIMEOUT')
    elif 'error' in point:
      row.append('ERROR')
    t.add_row(row)
  for c in PARAMS:
    t.sortby = c
  with open('fattree.txt', 'w+') as f:
    f.write(str(t))
  

def plot(data, methods):
  f = open("bayonet.txt", "w")

  times = defaultdict(lambda: defaultdict(list))
  time_mean = defaultdict(dict)
  time_std = defaultdict(dict)
  plt.figure(figsize=(6,3))
  ax = plt.subplot(111)    
  ax.get_xaxis().tick_bottom()    
  ax.get_xaxis().set_ticks_position('both')
  ax.get_yaxis().tick_left() 
  ax.get_yaxis().set_ticks_position('both')
  ax.tick_params(axis='both', which='both', direction='in')
  ax.set_xscale("log", nonposx='clip')
  ax.set_yscale("log", nonposy='clip')
  for pt in data:
    times[pt['method']][pt['num_switches']].append(pt['time'])
  for method, sw_times in times.items():
    if method in methods:
      for sw, time_vals in sw_times.items():
        time_mean[method][sw] = np.mean(time_vals)
        time_std[method][sw] = np.std(time_vals)

  for method, sw_times in sorted(time_mean.items()):
    sorted_pts = sorted(sw_times.items())
    xs, ys = zip(*sorted_pts)
    if ys[-1] >= 3599:
      ys = ys[:-1]
      xs = xs[:-1]
    errors = [time_std[method][x] for x in xs]
    plt.errorbar(xs, ys, yerr=errors, label = label_of_method[method],
                 marker=markers[method], color=colors[method], zorder=10)
    # Also dump data to a file
    for idx in range(len(xs)):
      f.write(method + "\t" + str(xs[idx]) + "\t" + str(ys[idx]) + "\n") 
   
  ax.text(400, 500, 'Time limit = 3600s', horizontalalignment='center', verticalalignment='center', color='gray')
  ax.annotate("", xy=(400, 3600), xytext=(400, 1000), arrowprops=dict(arrowstyle="->", color='gray'))

  # Customize plots
  ax.grid(alpha=0.2)
  plt.xlim(1, 100000)
  plt.ylim(0.5, 10000)
  ax.fill_between([0,100000], 3600, ax.get_ylim()[1], facecolor='red', alpha=0.2)
  ax.spines['bottom'].set_color('#999999')
  ax.spines['top'].set_color('#999999') 
  ax.spines['right'].set_color('#999999')
  ax.spines['left'].set_color('#999999')

  plt.xlabel("Number of switches")
  plt.ylabel("Time (seconds)")
  leg = plt.legend(fancybox=True, loc='best')
  leg.get_frame().set_alpha(0.9)
  f.close()
  plt.savefig('bayonet.pdf', bbox_inches='tight')


def main():
  data = parse_output(DATA_DIR)
  dump(data)
  # plot(data, methods)

if __name__ == "__main__":
  main()