function pubkey --description 'Copy ssh public key to clipboard' # TODO: add support of onepassword keys
  if test -f ~/.ssh/id_rsa.pub
    cat ~/.ssh/id_rsa.pub | pbcopy; and echo '=> Public key copied to clipboard.'
  else if test -f ~/.ssh/id_ed25519.pub
    cat ~/.ssh/id_ed25519.pub | pbcopy; and echo '=> Public key copied to clipboard.'
  else
    echo 'No public key found.'
  end
end
