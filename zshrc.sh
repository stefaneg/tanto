export TANTO_HOME=~/src/github.com/stefaneg/tanto

export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"

[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

alias j "autojump"

export AWS_PROFILE=gulli

autoload bashcompinit && bashcompinit
autoload -Uz compinit && compinit
complete -C '/usr/local/bin/aws_completer' aws

alias kubectl="minikube kubectl --"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

. $TANTO_HOME/tanto.sh

eval "$(starship init zsh)"
