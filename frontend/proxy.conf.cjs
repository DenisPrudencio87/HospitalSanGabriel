module.exports = {
  '/api': {
    target: `http://127.0.0.1:${process.env.API_PORT || '8000'}`,
    secure: false,
    changeOrigin: true,
  },
};
