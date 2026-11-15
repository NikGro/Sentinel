import { render } from 'preact';
import 'maplibre-gl/dist/maplibre-gl.css';
import { App } from './App';
import './styles.css';

render(<App />, document.getElementById('app')!);
