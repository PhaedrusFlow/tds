#! /usr/bin/env bash
# #################################################################
# /qompassai/.GH/PF/tds/scripts/gpclient.sh
# Qompass AI Gpclient Script
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# #################################################################
sudo gpclient --fix-openssl connect telecom.remotevpn.tds.net --os Windows --csd-wrapper /usr/lib/gpclient/hipreport.sh
