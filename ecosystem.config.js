module.exports = {
  apps: [
    {
      name: 'hardhat-development',
      script: './node_modules/.bin/hardhat',
      args: 'node --hostname 172.30.30.200',
      // args: 'node',
      watch: false,
      instance: 1,
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      exec_mode: 'cluster',
    },

    {
      name: 'hardhat-test',
      script: './node_modules/.bin/hardhat',
      args: 'node --hostname 172.30.30.201 --port 8545',
      // args: 'node --port 8090',
      watch: false,
      instance: 1,
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      exec_mode: 'cluster',
    },
  ],
}
