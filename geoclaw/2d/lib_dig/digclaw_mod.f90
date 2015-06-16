! ============================================================================
!  Program:     digclaw_mod
!  File:        geoclaw_mod.f90
!  Created:     2012-04-10
!  Author:      David George
! ============================================================================
!      Copyright (C)  2012-04-10 David George <dgeorge@uw.edu>
!
!  Distributed under the terms of the Berkeley Software Distribution (BSD)
!  license
!                     http://www.opensource.org/licenses/
! ============================================================================

module digclaw_module

   use geoclaw_module

   implicit none

    ! ========================================================================
    ! General digclaw parameters
    ! ========================================================================
    double precision :: rho_s,rho_f,phi_bed,theta_input,delta,kappita
    double precision :: mu,alpha,m_crit,c1,m0,alpha_seg,sigma_0,phi_seg_coeff

    integer :: init_ptype,p_initialized,bed_normal
    double precision :: init_pmax_ratio,init_ptf2,init_ptf,init_pmin_ratio
    double precision :: grad_eta_max,cohesion_max,grad_eta_ave,eta_cell_count

    integer, parameter ::  i_dig    = 4 !Start of digclaw aux variables
    integer, parameter ::  i_phi    = i_dig
    integer, parameter ::  i_theta  = i_dig + 1
    integer, parameter ::  i_tau_cx     = i_dig + 2
    integer, parameter ::  i_tau_cy   = i_dig + 3
    integer, parameter ::  i_taudir_x = i_dig + 4
    integer, parameter ::  i_taudir_y = i_dig + 5
    integer, parameter ::  DIG_PARM_UNIT = 78


contains

    ! ========================================================================
    !  set_dig(fname)
    ! ========================================================================
    !  Reads in user parameters from the given file name if provided
    ! ========================================================================
    subroutine set_dig(fname)

         implicit none

         ! Input
         character*25, intent(in), optional :: fname

         ! Locals
         double precision :: deg2rad
         integer, parameter :: iunit = 127
         character*25 :: file_name
         logical :: found_file


         deg2rad = pi/180.d0

         ! Read user parameters from setgeo.data
         if (present(fname)) then
            file_name = fname
         else
            file_name = 'setdig.data'
         endif
         inquire(file=file_name,exist=found_file)
         if (.not. found_file) then
            print *, 'You must provide a file ', file_name
            stop
         endif

         call opendatafile(iunit, file_name)

         read(iunit,*) rho_s
         read(iunit,*) rho_f
         read(iunit,*) phi_bed
         phi_bed = deg2rad*phi_bed
         read(iunit,*) theta_input
         theta_input = deg2rad*theta_input
         read(iunit,*) delta
         read(iunit,*) kappita
         read(iunit,*) mu
         read(iunit,*) alpha
         read(iunit,*) m_crit
         read(iunit,*) c1
         read(iunit,*) m0
         read(iunit,*) sigma_0
         read(iunit,*) alpha_seg
         read(iunit,*) bed_normal
         read(iunit,*) phi_seg_coeff
         close(iunit)
         alpha_seg = 1.0 - alpha_seg

         open(unit=DIG_PARM_UNIT,file='fort.dig',status="unknown",action="write")

         write(DIG_PARM_UNIT,*) ' '
         write(DIG_PARM_UNIT,*) '--------------------------------------------'
         write(DIG_PARM_UNIT,*) 'SETDIG:'
         write(DIG_PARM_UNIT,*) '---------'
         write(DIG_PARM_UNIT,*) '    rho_s:',rho_s
         write(DIG_PARM_UNIT,*) '    rho_f:',rho_f
         write(DIG_PARM_UNIT,*) '    phi_bed:', phi_bed/deg2rad
         write(DIG_PARM_UNIT,*) '    theta_input:', theta_input/deg2rad
         write(DIG_PARM_UNIT,*) '    delta:', delta
         write(DIG_PARM_UNIT,*) '    kappita:', kappita
         write(DIG_PARM_UNIT,*) '    mu:', mu
         write(DIG_PARM_UNIT,*) '    alpha:', alpha
         write(DIG_PARM_UNIT,*) '    m_crit:', m_crit
         write(DIG_PARM_UNIT,*) '    c1:', c1
         write(DIG_PARM_UNIT,*) '    m0:', m0
         write(DIG_PARM_UNIT,*) '    sigma_0:', sigma_0
         write(DIG_PARM_UNIT,*) '    alpha_seg:', alpha_seg
         write(DIG_PARM_UNIT,*) '    bed_normal:', bed_normal
         write(DIG_PARM_UNIT,*) '    phi_seg_coeff:', phi_seg_coeff


   end subroutine set_dig

    ! ========================================================================
    !  set_pinit(fname)
    ! ========================================================================
    !  Reads in user parameters from the given file name if provided
    ! ========================================================================
   subroutine set_pinit(fname)

        implicit none

        ! Input
        character*25, intent(in), optional :: fname

        ! Locals
        integer, parameter :: iunit = 127
        character*25 :: file_name
        logical :: found_file


         ! Read user parameters from setgeo.data
         if (present(fname)) then
            file_name = fname
         else
            file_name = 'setpinit.data'
         endif
         inquire(file=file_name,exist=found_file)
         if (.not. found_file) then
            print *, 'You must provide a file ', file_name
            stop
         endif

         call opendatafile(iunit, file_name)
         read(iunit,*) init_ptype
         read(iunit,*) init_pmax_ratio
         read(iunit,*) init_ptf
         read(iunit,*) init_ptf2
         close(unit=iunit)

         p_initialized = 0
         init_pmin_ratio = 1.d16
         grad_eta_max = 0.0
         cohesion_max = 0.0
         grad_eta_ave = 0.0
         eta_cell_count = 1.e-6


         write(DIG_PARM_UNIT,*) ' '
         write(DIG_PARM_UNIT,*) '--------------------------------------------'
         write(DIG_PARM_UNIT,*) 'SETPINIT:'
         write(DIG_PARM_UNIT,*) '---------'
         write(DIG_PARM_UNIT,*) '    init_ptype:',init_ptype
         write(DIG_PARM_UNIT,*) '    init_pmax_ratio:',init_pmax_ratio
         write(DIG_PARM_UNIT,*) '    init_ptf:',init_ptf
         close(DIG_PARM_UNIT)



   end subroutine set_pinit


   !====================================================================
   !subroutine admissibleq
   !accept solution q, return q in admissible space
   !====================================================================

   subroutine admissibleq(h,hu,hv,hm,p,u,v,m,theta)

      implicit none

      !i/o
      double precision, intent(in) :: theta
      double precision, intent(inout) :: h,hu,hv,hm,p
      double precision, intent(out) :: u,v,m

      !Locals
      double precision :: mlo,mhi,hlo,pmax,phi,plo,rho,dry_tol,m_min,gmod

      gmod = grav
      dry_tol = drytolerance
      if (bed_normal.eq.1) gmod = grav*dcos(theta)

      if (h.le.dry_tol) then
         h =  0.0*max(h,0.d0)
         hu = 0.d0
         hv = 0.d0
         hm = h*m0
         p  = h*gmod*rho_f
         u = 0.d0
         v = 0.d0
         m = m0
         return
      endif

      u = hu/h
      v = hv/h
      m = hm/h

      !mlo = 1.d-3
      mlo = 1.d-16
      mhi = 1.d0 - mlo

      if (m.lt.mlo) then
         m = dmax1(m,mlo)
         !m = (m**2 + mlo**2)/(2.d0*mlo)
         hm = h*m
      elseif (m.gt.mhi) then
         m = dmin1(m,1.d0)
         !m = 1.d0 - ((1.d0-mhi)**2 + (1.d0-m)**2)/(2.d0*(1.d0-mhi))
         hm = h*m
      endif

      rho = rho_s*m + (1.d0-m)*rho_f
      pmax = rho*gmod*h
      plo = rho_f*dry_tol*gmod*dry_tol
      phi = pmax - plo
      if (p.lt.plo) then
         p = dmax1(0.d0,p)
         !p = dmax1(-5.0*pmax,p)
         !p = (p**2 + plo**2)/(2.d0*plo)
      elseif (p.gt.phi) then
         p = dmin1(pmax,p)
         !p = pmax - ((pmax-p)**2+ (pmax-phi)**2)/(2.d0*(pmax-phi))
      endif

      return

   end subroutine admissibleq

   !====================================================================
   ! subroutine auxeval: evaluates the auxiliary variables as functions
   !                     of the solution vector q
   !====================================================================

   subroutine auxeval(h,u,v,m,p,phi_bed,theta,kappa,S,rho,tanpsi,D,tau,sigbed,kperm,compress,pm)

      implicit none

      !i/o
      double precision, intent(inout) :: pm
      double precision, intent(in)  :: h,u,v,m,p,phi_bed,theta
      double precision, intent(out) :: S,rho,tanpsi,D,tau,kappa
      double precision, intent(out) :: sigbed,kperm,compress

      !local
      double precision :: m_eqn,vnorm,gmod,sigbedc,hbounded,shear,tanphi
      double precision :: seg,pmlin,pmtan,pmtanh,pmtanh01

      if (h.lt.drytolerance) return

      hbounded = h!max(h,0.1)
      gmod=grav
      if (bed_normal.eq.1) gmod=grav*dcos(theta)
      vnorm = dsqrt(u**2.0 + v**2.0)
      rho = rho_s*m + rho_f*(1.d0-m)
      shear = 2.0*vnorm/hbounded
      sigbed = dmax1(0.d0,rho*gmod*h - p)
      sigbedc = rho_s*(shear*delta)**2.0 + sigbed
      if (sigbedc.gt.0.0) then
         S = (mu*shear/(sigbedc))
      else
         S = 0.d0
      endif
      !Note: m_eqn = m_crit/(1+sqrt(S))
      !From Boyer et. al
      !S = 0.0
      m_eqn = m_crit/(1.d0 + sqrt(S))
      !if (m.gt.m_eqn) write(*,*) 'm,m_eqn,S:',m,m_eqn,S,sigbed,shear
      tanpsi = c1*(m-m_eqn)*tanh(shear/0.1)
      pm = max(0.0,pm)
      pm = min(1.0,pm)
      if (alpha_seg==1.0) then
         seg = 0.0
      else
         seg = 1.0
      endif
      pmlin = seg*2.0*(pm-0.5)
      pmtan = seg*0.06*(tan(3.*(pm-0.5)))
      pmtanh = seg*tanh(3.*pmlin)
      pmtanh01 = seg*0.5*(tanh(8.0*(pm-0.75))+1.0)

      kperm = 10**(pmtanh01)*kappita*exp(-(m-0.60)/(0.04))

      !kperm = kperm + 1.0*pm*kappita
      !compress = alpha/(sigbed + 1.d5)
      compress = alpha/(m*(sigbed +  sigma_0))

      if (m.le.1.d-99) then
         kperm = 0.0
         tanpsi = 0.0
      endif

      if (p_initialized.eq.0.and.vnorm.le.0.d0) then
      !if (vnorm.le.0.d0) then
         tanpsi = 0.d0
         D = 0.d0
      elseif (h*mu.gt.0.d0) then
         D = 2.0*(kperm/(mu*h))*(rho_f*gmod*h - p)
      else
         D = 0.d0
      endif
      
      tanphi = dtan(phi_bed + datan(tanpsi)) + phi_seg_coeff*pmtanh01*dtan(phi_bed)
      !if (S.gt.0.0) then
      !   tanphi = tanphi + 0.38*mu*shear/(shear + 0.005*sigbedc)
      !endif

      tau = dmax1(0.d0,sigbed*tanphi)

      !tau = (grav/gmod)*dmax1(0.d0,sigbed*tanphi)
      !kappa: earth pressure coefficient
      !if (phi_int.eq.phi_bed) then
      !   sqrtarg = 0.d0
      !else
      !   sqrtarg = 1.d0-(dcos(phi_int)**2)*(1.d0 + dtan(phi_bed)**2)
      !endif

      !kappa = (2.d0 - pm*2.d0*dsqrt(sqrtarg))/(dcos(phi_int)**2)
      !kappa = kappa - 1.d0
      kappa = 1.d0

   end subroutine auxeval


   !====================================================================
   !subroutine psieval: evaluate the source term
   !====================================================================

   subroutine psieval(tau,rho,D,tanpsi,kperm,compress,h,u,m,psi)

      implicit none

      !i/o
      double precision, intent(out) :: psi(4)
      double precision, intent(in)  :: tau,rho,D,tanpsi,kperm,compress
      double precision, intent(in)  :: h,u,m

      !local
      double precision :: taushear,drytol,vnorm

      drytol = drytolerance

      taushear = (tau/rho)*dsign(1.d0,u)
      vnorm = dabs(u)
      if (h.lt.drytol.or..true.) then
         psi(1) = 0.d0
         psi(2) = 0.d0
         psi(3) = 0.d0
         psi(4) = 0.d0
      else
         psi(1) =  D*(rho-rho_f)/rho
         psi(2) =  u*D*(rho-rho_f)/rho
         psi(3) = -D*m*(rho_f/rho)
         psi(4) = 0.d0
      endif

   end subroutine psieval

   ! ========================================================================
   !  calc_taudir
   ! ========================================================================
   !  Determines the resistive force vector for static cells
   !  outputs direction cosines at each interface
   ! ========================================================================

subroutine calc_taudir(maxmx,maxmy,meqn,mbc,mx,my,xlower,ylower,dt,dx,dy,q,maux,aux)

      implicit none

      !Input
      double precision :: dt,dx,dy,xlower,ylower
      double precision :: q(1-mbc:maxmx+mbc, 1-mbc:maxmy+mbc, meqn)
      double precision :: aux(1-mbc:maxmx+mbc,1-mbc:maxmy+mbc,maux)
      integer :: maxmx,maxmy,mx,my,mbc,meqn,maux

      !Locals
      double precision :: gmod,dry_tol
      double precision :: h,hu,hv,hm,p,b,eta
      double precision :: hL,huL,hvL,hmL,pL,bL,etaL
      double precision :: hR,huR,hvR,hmR,pR,bR,etaR
      double precision :: hB,huB,hvB,hmB,pB,bB,etaB
      double precision :: hT,huT,hvT,hmT,pT,bT,etaT

      double precision :: u,v,m
      double precision :: uL,vL,mL
      double precision :: uR,vR,mR
      double precision :: uB,vB,mB
      double precision :: uT,vT,mT
      double precision :: thetaL,thetaB,theta
      double precision :: tau,tauL,tauR,tauB,tauT,rho,rhoL,rhoR,rhoT,rhoB
      double precision :: phi,kappa,S,tanpsi,D,sigbed,kperm,compress,pm
      double precision :: Fx,Fy,FxL,FxR,FyL,FyR,FyC,FxC,dot,net_force,taubound


      integer :: i,j

      dry_tol = drytolerance
      gmod = grav


      do i=2-mbc,mx+mbc-1
         do j=2-mbc,my+mbc-1
            

            h = q(i,j,1)
            hu = q(i,j,2)
            hv = q(i,j,3)
            if (h<dry_tol) then
               hu=0.0
               hv=0.0
            endif
            hm = q(i,j,4)
            p  = q(i,j,5)
            b = aux(i,j,1)
            eta = h+b
            phi = aux(i,j,i_phi)

            hL = q(i-1,j,1)
            huL= q(i-1,j,2)
            hvL= q(i-1,j,3)
            hmL = q(i-1,j,4)
            pL  = q(i-1,j,5)
            bL = aux(i-1,j,1)
            etaL= hL+bL
            if (hL<dry_tol) then
               etaL = min(etaL,eta)
            endif

            hR = q(i+1,j,1)
            huR= q(i+1,j,2)
            hvR= q(i+1,j,3)
            hmR = q(i+1,j,4)
            pR  = q(i+1,j,5)
            bR = aux(i+1,j,1)
            etaR= hR+bR
            if (hR<dry_tol) then
               etaR = min(etaR,eta)
            endif

            hB = q(i,j-1,1)
            huB= q(i,j-1,2)
            hvB= q(i,j-1,3)
            hmB = q(i,j-1,4)
            pB  = q(i,j-1,5)
            bB = aux(i,j-1,1)
            etaB= hB+bB
            if (hB<dry_tol) then
               etaB = min(etaB,eta)
            endif

            hT = q(i,j+1,1)
            huT= q(i,j+1,2)
            hvT= q(i,j+1,3)
            hmT = q(i,j+1,4)
            pT  = q(i,j+1,5)
            bT = aux(i,j+1,1)
            etaT= hT+bT
            if (hT<dry_tol) then
               etaT = min(etaT,eta)
            endif

            if (h<dry_tol) then
               eta = min(etaL,eta)
               eta = min(etaB,eta)
            endif

            if ((h+hL+hB+hR+hT)<dry_tol) then
               aux(i,j,i_taudir_x) = 0.0
               aux(i,j,i_taudir_y) = 0.0
               aux(i,j,i_tau_cx) = 1.0
               aux(i,j,i_tau_cy) = 1.0
               cycle
            endif

            if (bed_normal.eq.1) then
               theta = aux(i,j,i_theta)
               thetaL = aux(i-1,j,i_theta)
               thetaB = aux(i,j-1,i_theta)
               gmod = grav*cos(theta)
            else
               theta = 0.d0
               thetaL = 0.d0
               thetaB = 0.d0
            endif

            pm = 0.5 !does not effect tau. only need tau in different cells
            call admissibleq(h,hu,hv,hm,p,u,v,m,theta)
            call admissibleq(hL,huL,hvL,hmL,pL,uL,vL,mL,theta)
            call admissibleq(hB,huB,hvB,hmL,pB,uB,vB,mB,theta)
            call admissibleq(hR,huR,hvR,hmR,pR,uR,vR,mR,theta)
            call admissibleq(hT,huT,hvT,hmT,pT,uT,vT,mT,theta)


            call auxeval(h,u,v,m,p,phi,theta,kappa,S,rho,tanpsi,D,tau,sigbed,kperm,compress,pm)
            call auxeval(hL,uL,vL,mL,pL,phi,theta,kappa,S,rhoL,tanpsi,D,tauL,sigbed,kperm,compress,pm)
            call auxeval(hR,uR,vR,mR,pR,phi,theta,kappa,S,rhoR,tanpsi,D,tauR,sigbed,kperm,compress,pm)
            call auxeval(hB,uB,vB,mB,pB,phi,theta,kappa,S,rhoB,tanpsi,D,tauB,sigbed,kperm,compress,pm)
            call auxeval(hT,uT,vT,mT,pT,phi,theta,kappa,S,rhoT,tanpsi,D,tauT,sigbed,kperm,compress,pm)
            
            !minmod gradients
            FxC = -gmod*h*(EtaR-EtaL)/(2.0*dx) + gmod*h*sin(theta)
            FyC = -gmod*h*(EtaT-EtaB)/(2.0*dy)

            FxL = -gmod*0.5*(h+hL)*(Eta-EtaL)/(dx) + gmod*0.5*(h+hL)*sin(theta)
            FyL = -gmod*0.5*(h+hB)*(Eta-EtaB)/(dy)

            FxR = -gmod*0.5*(h+hR)*(EtaR-Eta)/(dx) + gmod*0.5*(h+hR)*sin(theta)
            FyR = -gmod*0.5*(h+hT)*(EtaT-Eta)/(dy)

            if (FxL*FxR.gt.0.0) then
               Fx = dsign(min(abs(FxL),abs(FxR)),FxL)
            else
               Fx = 0.0
            endif

            if (FyL*FyR.gt.0.0) then
               Fy = dsign(min(abs(FyL),abs(FyR)),FyL)
            else
               Fy = 0.0
            endif

            net_force = sqrt((FxC + hu/dt)**2 + (FyC + hv/dt)**2)
            taubound = (1./sqrt(2.0))*min(1.0,rho*net_force/max(tau,1.d-16))
            net_force = sqrt((FxC + hu/dt)**2 + (FyC + hv/dt)**2)

            if (net_force>0.0) then
               aux(i,j,i_tau_cx) = -taubound*(hu/dt)/net_force 
               aux(i,j,i_tau_cy) = -taubound*(hv/dt)/net_force 
               aux(i,j,i_taudir_x) = -taubound*FxL/net_force
               aux(i,j,i_taudir_y) = -taubound*FyL/net_force
            else
               aux(i,j,i_tau_cx) = 0.0
               aux(i,j,i_tau_cy) = 0.0
               aux(i,j,i_taudir_x) = 0.0
               aux(i,j,i_taudir_y) = 0.0
            endif 
            write(*,*) 'Fx,Fy:', aux(i,j,i_taudir_x), aux(i,j,i_taudir_y)
            write(*,*) 'ux,uy:', aux(i,j,i_tau_cx), aux(i,j,i_tau_cy)

         enddo
      enddo

end subroutine calc_taudir


   ! ========================================================================
   !  calc_pmin
   ! ========================================================================
   !  Determines minimum pore pressure for mobilization
   !  Determines factor of safety and cohesion for static states
   ! ========================================================================

subroutine calc_pmin(maxmx,maxmy,meqn,mbc,mx,my,xlower,ylower,dx,dy,q,maux,aux)


      implicit none

      !Input
      double precision :: dx,dy,xlower,ylower
      double precision :: q(1-mbc:maxmx+mbc, 1-mbc:maxmy+mbc, meqn)
      double precision :: aux(1-mbc:maxmx+mbc,1-mbc:maxmy+mbc,maux)
      integer :: maxmx,maxmy,mx,my,mbc,meqn,maux

      !Locals
      double precision :: h,hL,hR,hu,hv,b,bL,bR,bT,bB,hT,hB
      double precision :: phi,theta,rho
      double precision :: gmod,dry_tol
      double precision :: EtaL,EtaR,EtaT,EtaB,Eta
      double precision :: detadx,detadxL,detadxR,detady,detadyT,detadyB
      double precision :: grad_eta


      integer :: i,j

      dry_tol = drytolerance
      gmod = grav
      rho = m0*rho_s + (1.0-m0)*rho_f

      do i=1,mx
         do j=1,my

            h = q(i,j,1)
            hL = q(i-1,j,1)
            hR = q(i+1,j,1)
            if (h<dry_tol) then
               !aux(i,j,i_fs) = 10.0
               cycle
            endif

            hu = q(i,j,2)
            hv = q(i,j,3)

            if ((hu**2+hv**2)>0.0) then
               !aux(i,j,i_fs) = 0.0
               cycle
            endif

            b = aux(i,j,1)
            bR = aux(i+1,j,1)
            bL = aux(i-1,j,1)
            phi = aux(i,j,i_phi)

            if ((phi)==0.0) then
               !aux(i,j,i_fs) = 0.0
               init_pmin_ratio = 0.0
               cycle
            endif

            hT = q(i,j+1,1)
            bT = aux(i,j+1,1)
            hB = q(i,j-1,1)
            bB = aux(i,j-1,1)

            if (bed_normal.eq.1) then
               theta = aux(i,j,i_theta)
               gmod = grav*cos(theta)
            else
               theta = 0.d0
            endif

            Eta  = h+b
            !---------max deta/dx-------------------
            EtaR = hR+bR
            EtaL = hL+bL
            if (hR<=dry_tol) then
               EtaR = min(Eta,bR)
            endif
            if (hL<=dry_tol) then
               EtaL = min(Eta,bL)
            endif
            detadxR = (EtaR-Eta)/dx -tan(theta)
            detadxL = (Eta-EtaL)/dx -tan(theta)
            if (detadxR*detadxL<=0.0) then
               detadx = 0.0
            elseif (abs(detadxR)>abs(detadxL)) then
               detadx = detadxL
            else
               detadx = detadxR
            endif


            !---------max deta/dy-------------------
            EtaT = hT+bT
            EtaB = hB+bB
            if (hT<=dry_tol) then
               EtaT = min(Eta,bT)
            endif
            if (hB<=dry_tol) then
               EtaB = min(Eta,bB)
            endif
            detadyT = (EtaT-Eta)/dy
            detadyB = (Eta-EtaB)/dy
            if (detadyT*detadyB<=0.0) then
               detady = 0.0
            elseif (abs(detadyT)>abs(detadyB)) then
               detady = detadyB
            else
               detady = detadyT
            endif

            grad_eta = sqrt(detadx**2 + detady**2)
            grad_eta_ave = grad_eta_ave + grad_eta/tan(phi)
            eta_cell_count = eta_cell_count + 1.0

            grad_eta_max = max(grad_eta_max,grad_eta/tan(phi))

            init_pmin_ratio = min(init_pmin_ratio, 1.0-grad_eta/tan(phi))

            if (grad_eta>0.0) then
               !aux(i,j,i_fs) = tan(phi)/grad_eta
            else
               !aux(i,j,i_fs) = 10.0
            endif
         enddo
      enddo

      if (init_ptype==2.or.init_ptype==4) then
         init_pmin_ratio = 1.0-(grad_eta_ave/eta_cell_count)
      endif
      if (init_ptype>0) then
         write(*,*) '--------------------------------------------'
         write(*,*) 'hydrostatic liquefaction ratio:', rho_f/rho
         write(*,*) 'initiation liquefaction  ratio:',init_pmin_ratio, grad_eta_ave
         write(*,*) 'maximum surface slope angle:',180.*atan(tan(phi)*grad_eta_max)/3.14, grad_eta_max
         write(*,*) 'average failure liquefaction ratio:', 1.0-(grad_eta_ave/eta_cell_count) , eta_cell_count
         write(*,*) '--------------------------------------------'
      endif
   end subroutine calc_pmin


end module digclaw_module
