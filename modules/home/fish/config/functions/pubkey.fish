function pubkey --description 'Echo ssh public key'
  if type -q op
    op item get $hostname --fields 'public key'
  else if test -f ~/.ssh/id_rsa.pub
    cat ~/.ssh/id_rsa.pub
  else if test -f ~/.ssh/id_ed25519.pub
    cat ~/.ssh/id_ed25519.pub
  end
end
