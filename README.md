# Encrypts your folders and pushes them to your cloud storage
(... so no one can know the secrets you hide in your `~/Pictures`)

Usage:

``` shell
$ ./ecgo.sh -h
```

This simple script relies on two external tools;
[GnuPG](https://gnupg.org/), and [Rclone](https://rclone.org/). The
former handles encryption and decryption while the latter handles the
communication with Google Drive and other cloud storage platforms.

# How it works?
It turns your directory into a file using `tar`. Then it uses public
key cryptography to encrypt your directory using your public
key. Finally, it pushes the encrypted file to the cloud storage.

When you want to obtain the original directory the steps are as
follows:
- You download the `*.gpg` file from your cloud storage platform and
  pass it to this script. The `*.gpg` is unintelligible to anyone
  except for those who hold your secret key (it helps if it's only
  you).
- The script decrypts the file using your secret key (which may
  require some interaction with GnuPG on your side). Decryption
  process results in your original `*.tar.gz` file.
- The script turns `*.tar.gz` file back into a directory.

The script generates temporary files and stores them in whatever
location `mktemp` uses on your system.

# Security guarantees
Your encrypted file is as secure as the cryptography GnuPG uses to
encrypt it. You may for example use your `rsa3072` keys (see
[RSA](https://en.wikipedia.org/wiki/RSA_(cryptosystem))), which is
"fairly secure" ("except probably against [quantum
attacks](https://www.technologyreview.com/2019/05/30/65724/how-a-quantum-computer-could-break-2048-bit-rsa-encryption-in-8-hours/)").

# Why this script exists?
It exists to illustrate that "encrypting data at rest" can be done by
the cloud storage user who, for any reason, does not trust the cloud
storage provider.

# License
Public-domain software
