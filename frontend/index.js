import { backend } from 'declarations/backend';
import { AuthClient } from '@dfinity/auth-client';
import { Principal } from '@dfinity/principal';

let authClient;
let principal;

async function init() {
    authClient = await AuthClient.create();
    if (await authClient.isAuthenticated()) {
        handleAuthenticated();
    }
}

async function handleAuthenticated() {
    principal = authClient.getIdentity().getPrincipal();
    document.getElementById('principal-id').textContent = principal.toText();
    updateUserBalances();
}

async function updateUserBalances() {
    const tokenIds = ['ICP', 'TOKEN1', 'TOKEN2']; // Add more token IDs as needed
    const balancesList = document.getElementById('user-balances');
    balancesList.innerHTML = '';

    for (const tokenId of tokenIds) {
        const balance = await backend.getUserBalance(principal, tokenId);
        const li = document.createElement('li');
        li.textContent = `${tokenId}: ${balance ? balance.toString() : '0'}`;
        balancesList.appendChild(li);
    }
}

document.getElementById('create-token-btn').addEventListener('click', async () => {
    const tokenId = document.getElementById('create-token-id').value;
    const initialSupply = parseFloat(document.getElementById('create-token-supply').value);
    await backend.createToken(tokenId, initialSupply);
    alert(`Token ${tokenId} created with initial supply ${initialSupply}`);
});

document.getElementById('place-order-btn').addEventListener('click', async () => {
    const tokenId = document.getElementById('order-token-id').value;
    const isBuy = document.getElementById('order-type').value === 'buy';
    const amount = parseFloat(document.getElementById('order-amount').value);
    const price = parseFloat(document.getElementById('order-price').value);
    const orderId = await backend.placeOrder(tokenId, isBuy, amount, price);
    alert(`Order placed with ID: ${orderId}`);
});

document.getElementById('get-order-book-btn').addEventListener('click', async () => {
    const tokenId = document.getElementById('order-book-token-id').value;
    const orders = await backend.getOrderBook(tokenId);
    const orderBookDisplay = document.getElementById('order-book-display');
    orderBookDisplay.innerHTML = '';

    orders.forEach(order => {
        const orderElement = document.createElement('div');
        orderElement.textContent = `ID: ${order.id}, ${order.isBuy ? 'Buy' : 'Sell'}, Amount: ${order.amount}, Price: ${order.price}`;
        orderBookDisplay.appendChild(orderElement);
    });
});

init();
