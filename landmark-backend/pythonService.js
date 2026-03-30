const { spawn } = require('child_process');
const path = require('path');

async function execPython(imagePath) {
    return new Promise((resolve, reject) => {
        const pythonProcess = spawn('python', [path.join(__dirname, 'recognize.py'), imagePath]);

        let output = '';
        let errorOutput = '';

        pythonProcess.stdout.on('data', (data) => {
            output += data.toString();
        });

        pythonProcess.stderr.on('data', (data) => {
            errorOutput += data.toString();
        });

        pythonProcess.on('close', (code) => {
            if (code === 0) {
                try {
                    const result = JSON.parse(output);
                    resolve(result);
                } catch (e) {
                    reject(`Failed to parse output: ${e.message}`);
                }
            } else {
                reject(`Python script error: ${errorOutput}`);
            }
        });
    });
}

module.exports = { execPython };

