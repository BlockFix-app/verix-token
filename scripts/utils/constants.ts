import fs from 'fs';
import path from 'path';

const DEPLOYMENTS_FILE = path.join(__dirname, '../../deployments.json');

export async function saveDeploymentAddress(
  contractName: string,
  address: string
) {
  let deployments: any = {};
  
  if (fs.existsSync(DEPLOYMENTS_FILE)) {
    const content = fs.readFileSync(DEPLOYMENTS_FILE, 'utf8');
    deployments = JSON.parse(content);
  }

  const network = process.env.HARDHAT_NETWORK || 'localhost';
  
  if (!deployments[network]) {
    deployments[network] = {};
  }
  
  deployments[network][contractName] = address;
  
  fs.writeFileSync(
    DEPLOYMENTS_FILE,
    JSON.stringify(deployments, null, 2)
  );
}

export async function getDeploymentAddress(
  contractName: string
): Promise<string> {
  if (!fs.existsSync(DEPLOYMENTS_FILE)) {
    throw new Error('No deployments file found');
  }

  const content = fs.readFileSync(DEPLOYMENTS_FILE, 'utf8');
  const deployments = JSON.parse(content);
  
  const network = process.env.HARDHAT_NETWORK || 'localhost';
  
  if (!deployments[network] || !deployments[network][contractName]) {
    throw new Error(`No deployment found for ${contractName} on ${network}`);
  }
  
  return deployments[network][contractName];
}
