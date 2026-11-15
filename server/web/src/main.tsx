import { render } from 'preact';
import '@fontsource-variable/inter';
import { App } from './App';
import './styles.css';

render(<App />, document.getElementById('app')!);
