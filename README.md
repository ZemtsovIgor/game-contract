# CMD
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew update

brew doctor

export PATH="/usr/local/bin:$PATH"

brew install node

brew install git

npm install --global yarn

npm i -g truffle

npm i -g corepack

truffle dashboard

yarn install

yarn deploy --network truffle

yarn verify 0x423237005A35787fB706Fa5F6f436Fe75534daEe --network truffle

yarn whitelist-open --network truffle

curl 'https://api.bscscan.com/api?module=block&action=getblocknobytime&timestamp=1645570800&closest=before&apikey=SC8ZX9X543TBIBK6B7F8M4ICBWIZMYQ1SJ'

