// remote/src/Button.js
import React from "react";

export const Button = () => <button onClick={handleClick}>Hello</button>;

const handleClick = (e) => {
    console.log('this is:', e);
  };

export default Button;