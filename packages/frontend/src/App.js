
import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import Dashboard from './Dashboard';
import CreateMonitor from './CreateMonitor';
import Report from './Report';

function App() {
  return (
    <Router>
      <div className="App">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/create" element={<CreateMonitor />} />
          <Route path="/report/:monitorId" element={<Report />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
