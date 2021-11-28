from brownie import PooledDerivative, network, config, MockV3Aggregator
from scripts.helper import get_account, deploy_mocks, LOCAL_BLOCKCHAIN_ENVIROMENT


def deploy_pooled_derivative():
    account = get_account()
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIROMENT:
        price_feed_address = config["networks"][network.show_active()][
            "eth_usd_price_feed"
        ]
    else:
        deploy_mocks()
        price_feed_address = MockV3Aggregator[-1].address

    print(f"NetworK {network.show_active()}")
    fund_me = PooledDerivative.deploy(
        price_feed_address,
        "1:1 ETH USD",
        0,
        455,
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify"),
    )
    print(f"Contract deployed to {fund_me.address}")
    return fund_me


def main():
    deploy_pooled_derivative()
