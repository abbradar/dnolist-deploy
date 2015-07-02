{
  haskellPackageOverrides = self: super: {
    email-header = self.callPackage ./email-header {};
    email = self.callPackage ./email {};
    smtp = self.callPackage ./smtp {};
    dnolist = self.callPackage ./dnolist {};
  };

  packageOverrides = self: {
    dnolist-frontend = self.callPackage ./dnolist-frontend {
      ruby = self.ruby_2_2;
    };
  };
}
