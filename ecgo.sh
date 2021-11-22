#!/bin/bash
#
# Author: Novak Boškov <gnovak.boskov@gmail.com>
# Date: Dec, 2020.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
set -e

# defaults
encrypt_args=""
decrypt_args=""
output=""

help() {
    cat <<EOF
reping constantly pings the set of IP addresses and records the RTTs in termporary
files. In parallel, it periodically incorporates the termporary files into the
single output file that is useful for analysis. Ping sends an ICMP ECHO_REQUEST
each second.

Do not pass the same IP address multiple times. You will get only one single result.

Usage: ./reping.sh [-c] -o OUTPUT_FILE -p PERIOD IP_1 [IP_2 ...]

Parameters:
  IP_1 [IP_2] are the IP addresses to ping.

Options:
  -o file where the results will be stored.
  -p time interval to refresh the output file cumulatively.
  -c clean the artifacts of previous reping runs.

IP addresses in OUTPUT_FILE are modified. Any dots are replaced with dashes.

CAUTION: This program is designed to save disk space but is by no means optimal.
Given that:
- P is the period to refresh output file (e.g., 1 minute) (PERIOD),
- disk(P) is the file size that a call to ping produces in P,
- T is the multiple of P that tells how long we run this program for, and
- N is the number of IP addresses to ping.
Then the required disk space is 2*N*T*disk(P).
For example, for N=128, P=1m, T=60, and disk(P)=700B, we need 11MB of disk space.
That is, we will likely reach 1GB of disk space in 4 days of running this program.

A common usage patern is:
timeout --signal 9 1445m ./reping.sh -o my_output.dat -p 1h google.com yahoo.com

This will ping google.com and yahoo.com each second over one day and
refresh statistics each hour. The extra 5 minutes passed to the timeout command
are to give the statistics combinator some extra time to complete its task.
EOF
}

encrypt() {
    if [ -z "$SECRET_REMOTE_PATH" ]; then
        echo "SECRET_REMOTE_PATH is not specified, please do so."
        exit
    fi

    dir_path=$(cd $1; pwd)         # handle relative paths
    temp=$(mktemp -d)
    dir_name=$(basename $dir_path) # last dir in the path
    echo -e "===> Compressing $dir_path ..."
    tar -C $dir_path -czf $temp/$dir_name.tar.gz .
    echo -e "===> Created the compressed archive $temp/$dir_name.tar.gz"
    echo -e "\n===> Output from your GPG \
(it asks for the \"recipients\", which is yourself. Add yourself and press Enter on the next prompt):"
    gpg -e $temp/$dir_name.tar.gz

    # push to remote
    echo -e "===> Rclone pushes data to $SECRET_REMOTE_PATH/$dir_name.tar.gz.gpg ..."
    rclone -P copy $temp/$dir_name.tar.gz.gpg $SECRET_REMOTE_PATH
}

decrypt() {
    archive_path=$1
    temp=$(mktemp -d)
    base_name=$(basename $archive_path | cut -d. -f1)

    if [[ $archive_path == *":"* ]]; then # rsync path is in use if path contains semicolons
        echo "===> Downloading archive from $archive_path ..."
        download_path=$temp/$(basename $archive_path)
        rclone -P copy $archive_path $temp
        archive_path=$download_path
    fi

    # decryption
    echo -e "===> Output from your GPG (it asks for the decryption key):"
    gpg -d -o $temp/$base_name.tar.gz $archive_path

    if [ -z $output ]; then         # output is optional
        $output=$(pwd)
    else
        output="$(cd $output; pwd)" # get rid of trailing slashes if any
    fi

    # untaring
    echo -e "===> Untaring $output/$base_name ..."
    mkdir $output/$base_name
    tar -xvf $temp/$base_name.tar.gz -C $output/$base_name
}

# parse options
while getopts "he:d:o:" option; do
    case $option in
        e) encrypt_args=$OPTARG
           ;;
        d) decrypt_args=$OPTARG
           ;;
        o) output=$OPTARG
           ;;
        h | *) help
               exit
               ;;
    esac
done

# take actions
if ! [ -z "$encrypt_args" ]; then
    encrypt $encrypt_args
    exit
elif ! [ -z "$decrypt_args" ]; then
    decrypt $decrypt_args
    exit
elif ! [ -z "$output" ]; then
    help
    exit
fi
