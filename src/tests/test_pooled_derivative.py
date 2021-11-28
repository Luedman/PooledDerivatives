from scripts.helper import get_account, LOCAL_BLOCKCHAIN_ENVIROMENT
from scripts.deploy import deploy_pooled_derivative
from brownie import network, accounts, exceptions, PooledDerivative
import pytest


def test_funding():
    pooled_derivative = deploy_pooled_derivative()
    account = get_account()

    print(account)
    print(pooled_derivative.getContractDescription())
    investment = 24 * 14 ** 10
    tx = pooled_derivative.enterLongSide({"from": account, "value": investment})
    tx.info()
    tx = pooled_derivative.enterShortSide({"from": account, "value": investment})
    tx.info()
    tx.wait(1)

    print("Contract Funded")

    assert pooled_derivative.getResidual() == (0, 0)


def test_hedging():
    pooled_derivative = deploy_pooled_derivative()
    # pooled_derivative = PooledDerivative[-1]
    account = get_account()

    print(account)
    print(pooled_derivative.getContractDescription())
    investment = 245 * 14 ** 10
    tx = pooled_derivative.enterLongSide({"from": account, "value": investment})
    tx.info()
    tx = pooled_derivative.enterShortSide({"from": account, "value": 2 * investment})
    tx.info()
    tx.wait(2)

    print("Contract Funded")
    tx = pooled_derivative.callSettlement({"from": account})
    tx.info()

    assert pooled_derivative.getResidual() == (0, 0)
