#!/bin/bash
#
# Author: Novak Boškov <gnovak.boskov@gmail.edu>
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

function help {
    echo -e "Encrypts the directory and pushes it to Google Drive."
    echo -e "(or any other destination that Rclone can handle)\n"
    echo -e "PLEASE MAKE SURE THAT THE NAME OF THE DIRECTORY YOU ENCRYPT DOES NOT REVEAL UNWANTED INFORMATION.\n"
    echo -e "Uses GnuPG to encrypt the directory and Rclone to push the directory to Google Drive."
    echo -e "Both gpg and rclone need to be installed.\n"
    echo -e "Usage: ./ecgo.sh [options] <path_to_dir>\n"
    echo -e "Set SECRET_REMOTE_PATH environment variable to specify the rclone path where you want to put your ecnrypted data."
    echo -e "options:"
    echo -e "\t-h Prints the help message."
    echo -e "\t-e Encrypts the directory and pushes it to Google Drive."
    echo -e "\t-d Decrypts the directory."
}

function encrypt {
    if [ -z "$SECRET_REMOTE_PATH" ]; then
        echo "SECRET_REMOTE_PATH is not specified, please do so."
        exit
    fi

    dir_path=$(cd $1; pwd)         # handle relative paths
    temp=$(mktemp -d)
    dir_name=$(basename $dir_path) # last dir in the path
    echo -e "===> Compressing $dir_path ..."
    tar -czf $temp/$dir_name.tar.gz $dir_path
    echo -e "===> Created the compressed archive $temp/$dir_name.tar.gz"
    echo -e "\n===> Output from your GPG \
(it asks for the \"recipients\", which is yourself. Add yourself and press Enter on the next prompt):"
    gpg -e $temp/$dir_name.tar.gz

    # push to remote
    echo -e "===> Rclone pushes data to $SECRET_REMOTE_PATH ..."
    rclone -P copy $temp/$dir_name.tar.gz.gpg $SECRET_REMOTE_PATH
}

function decrypt {
    archive_path=$1
    base_name=$(basename $archive_path | cut -d. -f1)
    temp=$(mktemp -d)

    # decryption
    echo -e "===> Output from your GPG (it asks for the decryption key):"
    gpg -d -o $temp/$base_name.tar.gz $archive_path

    # untaring
    echo -e "===> Untaring the directory..."
    mkdir $base_name
    tar -xvf $temp/$base_name.tar.gz -C $base_name
}

while getopts "he:d:" option; do
    case $option in
        e) encrypt $OPTARG
           exit
           ;;
        d) decrypt $OPTARG
           exit
           ;;
        h | *) help
               exit
               ;;
    esac
done
