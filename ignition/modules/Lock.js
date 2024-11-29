const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {

  const myToken = m.contract("MyVestToken", [100000]);

  console.log(myToken);

  const vesting = m.contract("VestingContract", [myToken]);

  return { vesting };
});
