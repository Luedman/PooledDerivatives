from brownie import network, config, accounts, MockV3Aggregator

FORKED_LOCAL_ENV = ["mainnet-fork"]
LOCAL_BLOCKCHAIN_ENVIROMENT = ["development", "ganache-local"]

DECIMAL = 8
STARTING_PRICE = 20000000


def get_account():
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIROMENT + FORKED_LOCAL_ENV:
        return accounts[0]
    else:
        return accounts.add(config["wallets"]["from_key"])


def deploy_mocks():
    print(f"Active Network is {network.show_active}")
    print("Deploying mocks...")
    if len(MockV3Aggregator) <= 0:
        MockV3Aggregator.deploy(DECIMAL, STARTING_PRICE, {"from": get_account()})
        print("Mocks deployed!")
   