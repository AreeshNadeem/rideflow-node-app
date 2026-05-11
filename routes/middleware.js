function requireLogin(req, res, next) {
  if (!req.session.user) return res.redirect('/');
  next();
}

function requireRole(role) {
  return (req, res, next) => {
    if (!req.session.user) return res.redirect('/');
    if (req.session.user.role !== role) {
      req.session.flash = { type: 'danger', message: 'Access denied for this role.' };
      return res.redirect('/');
    }
    next();
  };
}

module.exports = { requireLogin, requireRole };
