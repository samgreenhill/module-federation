// eslint-disable-next-line @typescript-eslint/no-var-requires
const path = require('path');

module.exports = () => {
    return {
        entry: './src/app.ts',
        output: {
            path: path.resolve(__dirname, 'dist'),
            libraryTarget: 'commonjs2'
        },
        target: 'node14',
        module: {
            rules: [
                {
                    test: /\.(ts|tsx)$/i,
                    loader: 'ts-loader',
                    exclude: ['/node_modules/']
                }
            ]
        },
        resolve: {
            extensions: ['.tsx', '.ts', '.js']
        },
        devtool: 'source-map',
        optimization: {
            minimize: true
        }
    }
}