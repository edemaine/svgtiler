const light = null;
const dark = <path stroke="#000" d="M 7.5,0 L 0,7.5 M 15,0 L 0,15 M 22.5,0 L 0,22.5 M 30,0 L 0,30 M 37.5,0 L 0,37.5 M 45,0 L 0,45 M 45,7.5 L 7.5,45 M 45,15 L 15,45 M 45,22.5 L 22.5,45 M 45,30 L 30,45 M 45,37.5 L 37.5,45"/>;

function read(filename) {
  const dom = require(filename);
  // Strip off top level <svg>...</svg>
  console.assert(dom.type === 'svg');
  return dom.props.children;
}

(key, context) => {
  // Map blanks to empty string
  key = key.trim();
  if (key === '.') key = '';
  const piece = key.toLowerCase();
  return (
    <symbol viewBox="0 0 45 45">
      <rect width="45" height="45" fill="white" stroke="white"/>
      {(context.i + context.j) % 2 === 0 ? light : dark}
      {key.trim() && key !== '.' &&
       read(`./Chess_${piece}${piece === key ? "d" : "l"}t45.svg`)
      }
    </symbol>
  );
}