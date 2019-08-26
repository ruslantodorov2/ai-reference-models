#
# -*- coding: utf-8 -*-
#
# Copyright (c) 2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: EPL-2.0
#

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import os
import re
import platform as system_platform
import subprocess
import sys
from typing import List, Dict

NUMA_NODES_STR_ = "NUMA node(s)"
CPU_SOCKETS_STR_ = "Socket(s)"
CORES_PER_SOCKET_STR_ = "Core(s) per socket"
THREADS_PER_CORE_STR_ = "Thread(s) per core"
LOGICAL_CPUS_STR_ = "CPU(s)"


class CPUInfo():
    """CPU information class."""

    def __init__(self) -> None:
        """Initialize CPU information class."""
        self._binding_data = CPUInfo._sort_membind_info(self._get_core_membind_info())

    @staticmethod
    def _get_core_membind_info() -> List[List[str]]:
        """
        Return sorted information about cores and memory binding.

        E.g.
        CPU ID, Socket ID, Node ID, HT CPU ID,
        0  ,     0    ,    0   ,     0
        1  ,     0    ,    0   ,     1

        :return: list with cpu, sockets, ht core and memory binding information
        :rtype: List[List[str, Any]]
        """
        args = ["lscpu", "--parse=CPU,Core,Socket,Node"]
        process_lscpu = subprocess.check_output(args, universal_newlines=True).split("\n")

        # Get information about core, node, socket and cpu
        bind_info = []
        for line in process_lscpu:
            pattern = r"^([\d]+,[\d]+,[\d]+,[\d]+)"
            regex_out = re.search(pattern, line)
            if regex_out:
                bind_info.append(regex_out.group(1).strip().split(","))

        return bind_info

    @staticmethod
    def _sort_membind_info(membind_bind_info: List[List[str]]) -> List[List[Dict[str, int]]]:
        """
        Sore membind info data.

        :param membind_bind_info: raw membind info data
        :type membind_bind_info: List[List[str]]
        :return: sorted membind info
        :rtype: List[List[Dict[str, int]]]
        """
        membind_cpu_list = []
        nodes_count = int(max(element[2] for element in membind_bind_info)) + 1
        # Sort list by Node id
        for node_number in range(nodes_count):
            node_core_list = []
            core_info = {}
            for entry in membind_bind_info:
                cpu_id = int(entry[0])
                core_id = int(entry[1])
                node_id = int(entry[2])
                socket_id = int(entry[3])

                # Skip nodes other than current node number
                if node_number != node_id:
                    continue

                # Add core info
                if cpu_id == core_id:
                    core_info.update({
                        core_id: {
                            "cpu_id": cpu_id,
                            "node_id": node_id,
                            "socket_id": socket_id,
                        },
                    })
                else:
                    # Add information about Hyper Threading
                    core_info[core_id]["ht_cpu_id"] = cpu_id

            # Change dict of dicts to list of dicts
            for iterator in range(len(core_info)):
                curr_core_id = len(core_info) * node_number + iterator
                single_core_info = core_info.get(curr_core_id)
                if single_core_info:
                    node_core_list.append(single_core_info)

            membind_cpu_list.append(node_core_list)

        return membind_cpu_list

    @property
    def sockets(self) -> int:
        """
        Return count of sockets available on server.

        :return: available cores
        :rtype: int
        """
        available_sockets = len(self._binding_data)
        return int(available_sockets)

    @property
    def cores(self) -> int:
        """
        Return amount of cores available on server.

        :return: amount of cores
        :rtype: int
        """
        available_cores = self.cores_per_socket * self.sockets
        return int(available_cores)  # type: ignore

    @property
    def cores_per_socket(self) -> int:
        """
        Return amount of available cores per socket.

        :return: amount of cores
        :rtype: int
        """
        available_cores_per_socket = len(self._binding_data[0])
        return available_cores_per_socket

    @property
    def binding_information(self) -> List[List[Dict[str, int]]]:
        """
        Return information about cores and memory binding.

        Format:
        [
            [ # socket 0
                { # Core 0
                    "cpu_id": 0,
                    "node_id": 0,
                    "socket_id": 0,
                    "ht_cpu_id": 56
                }
            ],
            [ # socket 1
                { # Core 0
                    "cpu_id": 28,
                    "node_id": 1,
                    "socket_id": 1,
                    "ht_cpu_id": 84
                }
            ]
        ]

        :return: dict with cpu, sockets, ht core and memory binding information
        :rtype: List[List[Dict[str, int]]]
        """
        print(self._binding_data)
        return self._binding_data


class PlatformUtil:
    '''
    This module implements a platform utility that exposes functions that
    detects platform information.
    '''

    def __init__(self, args):
        self.args = args
        self.num_cpu_sockets = 0
        self.num_cores_per_socket = 0
        self.num_threads_per_core = 0
        self.num_logical_cpus = 0
        self.num_numa_nodes = 0

        os_type = system_platform.system()
        if "Windows" == os_type:
            self.windows_init()
        elif "Mac" == os_type or "Darwin" == os_type:
            self.mac_init()
        elif "Linux" == os_type:
            self.linux_init()
        else:
            raise ValueError("Unable to determine Operating system type.")

    def linux_init(self):
        # check to see if the lscpu command is present
        lscpu_path = ''
        lscpu_path_cmd = "command -v lscpu"
        try:
            lscpu_path = subprocess.check_output(lscpu_path_cmd, shell=True,
                                                 stderr=subprocess.STDOUT).\
                strip()
            if self.args.verbose:
                print("lscpu_path_cmd = {}\nlscpu located here: {}".format(lscpu_path_cmd, lscpu_path))
            if not os.access(lscpu_path, os.F_OK | os.X_OK):
                raise ValueError("{} does not exist or is not executable.".
                                 format(lscpu_path))

            lscpu_output = subprocess.check_output([lscpu_path],
                                                   stderr=subprocess.STDOUT)
            # handle python2 vs 3 (bytes vs str type)
            if isinstance(lscpu_output, bytes):
                lscpu_output = lscpu_output.decode('utf-8')

            cpu_info = lscpu_output.split('\n')

        except Exception as e:
            print("Problem getting CPU info: {}".format(e))
            sys.exit(1)

        # parse it
        for line in cpu_info:
            #      NUMA_NODES_STR_       = "NUMA node(s)"
            if line.find(NUMA_NODES_STR_) == 0:
                self.num_numa_nodes = int(line.split(":")[1].strip())
            #      CPU_SOCKETS_STR_      = "Socket(s)"
            elif line.find(CPU_SOCKETS_STR_) == 0:
                self.num_cpu_sockets = int(line.split(":")[1].strip())
            #      CORES_PER_SOCKET_STR_ = "Core(s) per socket"
            elif line.find(CORES_PER_SOCKET_STR_) == 0:
                self.num_cores_per_socket = int(line.split(":")[1].strip())
            #      THREADS_PER_CORE_STR_ = "Thread(s) per core"
            elif line.find(THREADS_PER_CORE_STR_) == 0:
                self.num_threads_per_core = int(line.split(":")[1].strip())
            #      LOGICAL_CPUS_STR_     = "CPU(s)"
            elif line.find(LOGICAL_CPUS_STR_) == 0:
                self.num_logical_cpus = int(line.split(":")[1].strip())

    def windows_init(self):
        raise NotImplementedError("Windows Support not yet implemented")

    def mac_init(self):
        raise NotImplementedError("Mac Support not yet implemented")
