// remote/src/Button.js
import React from "react";

export const Button = () => <button onClick={clickHandler}>Hello</button>;

const clickHandler = () => {
    // eslint-disable-next-line no-undef
    fetch(`${__webpack_public_path__}api`).then(resp => resp.text()).then(t => alert(t));
}

export default Button;