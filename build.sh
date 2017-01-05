#!/usr/bin/env bash
# rhoerbe/docker-template@github 2016-07-20
set -e

while getopts ":chn:pru" opt; do
  case $opt in
    c)
      CACHEOPT="--no-cache";;
    n)
      config_nr=$OPTARG
      re='^[0-9][0-9]$'
      if ! [[ $OPTARG =~ $re ]] ; then
         echo "error: -n argument is not a number in the range frmom 02 .. 99" >&2; exit 1
      fi
      config_opt="-n ${config_nr}"
      ;;
    p)
      print="True";;
    r)
      remove_img="True";;
    u)
      update_pkg="-u";;
    :)
      echo "Option -$OPTARG requires an argument"
      exit 1;;
    *)
      echo "usage: $0 [-h] [-i] [-n] [-p] [-r] [cmd]
   -c  do not use cache (build --no-cache)
   -h  print this help text
   -n  configuration number ('<NN>' in conf<NN>.sh)
   -p  print docker build command on stdout
   -r  remove existing image (-f)
   -u  update packages in docker build context
   unknow option $opt
   "
      exit 0;;
  esac
done

shift $((OPTIND-1))

# determine config script (there may be more than one to run multiple containers)
# if config_nr not given and there is only one file matching conf*.sh take this one
SCRIPTDIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
PROJROOT=$(cd $(dirname $SCRIPTDIR) && pwd)
cd $PROJROOT; confs=(conf*.sh); cd $OLDPWD
source $SCRIPTDIR/dscripts/conf_lib.sh  # load library functions

if [ ! -z ${config_nr} ]; then
    conf_script=conf${config_nr}.sh
    if [ ! -e "$PROJROOT/$conf_script" ]; then
        echo "$PROJROOT/$conf_script not found"
        exit 1
    fi
elif [ ${#confs[@]} -eq 1 ]; then
    conf_script=${confs[0]}
else
    echo "No or more than one (${#confs[@]}) conf*.sh: need to provide -n argument:"
    printf "%s\n" "${confs[@]}"
    exit 1
fi
source $PROJROOT/$conf_script

[ -e $PROJROOT/build_prepare.sh ] && $PROJROOT/build_prepare.sh $config_opt $update_pkg

if [ $(id -u) -ne 0 ]; then
    sudo="sudo"
fi

docker_build="docker build $BUILDARGS $CACHEOPT -t=$IMAGENAME ."
if [ "$print" = "True" ]; then
    echo $docker_build
fi

if [ "remove_img" = "True" ]; then
    ${sudo} docker rmi -f $IMAGENAME 2> /dev/null || true
fi

${sudo} $docker_build

echo "image: $IMAGENAME"
