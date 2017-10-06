# frozen_string_literal: true
#
# Copyright 2017 Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

# This file contains code documentation macros which are used through out the
# Rackstash code base. The file is loaded early in `.yardopts` so that the
# macros defined here should be available everywhere.

# @!macro resolves_procs_with_scope
#   If `$1` itself is a `Proc`, we will call it and use the returned value in
#   its place. If any of the (deeply nested) values of `$1` is a `Proc`, it will
#   likewise be called and the respective return value will be used there.
#
#   If you give the optional `scope` argument, each `Proc` object will be called
#   with the `scope` object as their only argument. If the `Proc` object doesn't
#   accept any arguments it will be executed in the context of the `scope`
#   object instead. If you leave the `scope` empty (or set it to `nil`), each
#   `Proc` object will be evaluated in the context of their original creation
#   environment.
