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
    integer, parameter ::  i_fs     = i_dig + 2
    integer, parameter ::  i_fsphi  = i_dig + 3
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
      double precision :: m_eqn,vnorm,gmod,sigbedc,hbounded,shear,tanphi,pmlin,pmtan,pmtanh,pmtanh01

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
      pmlin = 2.0*(pm-0.5)
      pmtan = 0.06*(tan(3.*(pm-0.5)))
      pmtanh = tanh(3.*pmlin)
      pmtanh01 = 0.5*(tanh(8.0*(pm-0.75))+1.0)
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

subroutine calc_taudir(maxmx,maxmy,meqn,mbc,mx,my,xlower,ylower,dx,dy,q,maux,aux)

      implicit none

      !Input
      double precision :: dx,dy,xlower,ylower
      double precision :: q(1-mbc:maxmx+mbc, 1-mbc:maxmy+mbc, meqn)
      double precision :: aux(1-mbc:maxmx+mbc,1-mbc:maxmy+mbc,maux)
      integer :: maxmx,maxmy,mx,my,mbc,meqn,maux

      !Locals
      double precision :: hL,h,huL,hu,hvL,hv,bL,b,hB,huB,hvB,bB,hm
      double precision :: thetaL,thetaB,theta
      double precision :: gmod,dry_tol
      double precision :: EtaL,Eta,EtaTL,EtaB
      double precision :: phi,rho,kappa,S,tanpsi,D,tau,sigbed,kperm,compress,pm
      double precision :: Fx,Fy,dot,u,v,m,p


      integer :: i,j

      dry_tol = drytolerance
      gmod = grav


      do i=2-mbc,mx+mbc
         do j=2-mbc,my+mbc
            !note: for edge valued aux, aux(i,. _x) is at i-1/2.

            h = q(i,j,1)
            hL = q(i-1,j,1)
            hB = q(i,j-1,1)
            if (h<=dry_tol.or.hL<=dry_tol.or.hB<=dry_tol) then
               aux(i,j,i_taudir_x) = 1.0
               aux(i,j,i_taudir_y) = 1.0
               aux(i,j,i_fsphi) = 0.0
               cycle
            endif

            hu = q(i,j,2)
            huL = q(i-1,j,2)
            huB = q(i,j-1,2)
            
            hv = q(i,j,3)
            hvL = q(i-1,j,3)
            hvB = q(i,j-1,3)

            b = aux(i,j,1)
            bL = aux(i-1,j,1)
            bB = aux(i,j-1,1)
            phi = aux(i,j,i_phi)

            hm = q(i,j,4)
            p  = q(i,j,5)


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


            if ((h>dry_tol).and.(hL>dry_tol))then
               Eta = h+b
               EtaL = hL+bL
            elseif (h>dry_tol) then
               Eta = h+b
               EtaL = min(Eta,hL+bL)
            else
               EtaL = hL+bL
               Eta = min(EtaL,h+b)
            endif

            if ((h>dry_tol).and.(hB>dry_tol))then
               Eta = h+b
               EtaB = hB+bB
            elseif (h>dry_tol) then
               Eta = h+b
               EtaB = min(Eta,hB+bB)
            else
               EtaB = hB+bB
               Eta = min(EtaB,h+b)
            endif

            Fx = -gmod*0.5*(h+hL)*((Eta-EtaL)/dx - sin(theta))
            Fy = -gmod*0.5*(h+hB)*(Eta-EtaB)/dy
            

            if ((hv**2+hu**2)>0.0) then
               aux(i,j,i_taudir_x) = -hu/sqrt(hv**2+hu**2)
               aux(i,j,i_taudir_y) = -hv/sqrt(hv**2+hu**2) 

               call admissibleq(h,hu,hv,hm,p,u,v,m,theta)
               pm = q(i,j,6)/q(i,j,1)
               call auxeval(h,u,v,m,p,phi,theta,kappa,S,rho,tanpsi,D,tau,sigbed,kperm,compress,pm)
               
               dot = Fx*hu + Fy*hv
               if (dot>0.0) then
                  !friction should oppose direction of velocity
                  !if net force is in same direction, split friction source term
                  !splitting is useful for small velocities and nearly balanced forces
                  !only split amount up to maximum net force for large velocities
                  aux(i,j,i_fsphi) = min(1.0,sqrt(Fx**2+Fy**2)*rho/max(tau,1.d-16))
               else
                  !net force is in same direction as friction
                  !if nearly balanced steady state not due to friction
                  !no splitting, integrate friction in src
                  aux(i,j,i_fsphi) = 0.0
               endif
               

            else 
               if ((Fx**2 + Fy**2)>0.d0) then
                  !friction should oppose net force. resolve in Riemann solver
                  aux(i,j,i_taudir_x) = -Fx/sqrt(Fx**2+Fy**2)
                  aux(i,j,i_taudir_y) = -Fy/sqrt(Fx**2+Fy**2) 
                  aux(i,j,i_fsphi) = 1.0
               else
                  !there is no motion or net force. resolve in src after Riemann 
                  aux(i,j,i_taudir_x) = 1.0
                  aux(i,j,i_taudir_y) = 1.0
                  aux(i,j,i_fsphi) = 0.0
               endif
               
            endif 
            
         enddo
      enddo

end subroutine calc_taudir

   ! ========================================================================
   !  calc_tausplit
   ! ========================================================================
   !  Determines splitting of tau for rp vs. src.
   ! ========================================================================

subroutine calc_tausplit(maxmx,maxmy,meqn,mbc,mx,my,xlower,ylower,dx,dy,q,maux,aux)


      implicit none

      !Input
      double precision :: dx,dy,xlower,ylower
      double precision :: q(1-mbc:maxmx+mbc, 1-mbc:maxmy+mbc, meqn)
      double precision :: aux(1-mbc:maxmx+mbc,1-mbc:maxmy+mbc,maux)
      integer :: maxmx,maxmy,mx,my,mbc,meqn,maux

      !Locals
      double precision :: h,hL,hR,hu,hv,hm,p,b,bL,bR,bT,bB,hT,hB,u,v,m
      double precision :: phi,theta,rho,kappa,S,tanpsi,D,tau,sigbed,kperm,compress,pm
      double precision :: gmod,dry_tol
      double precision :: EtaL,EtaR,EtaT,EtaB,Eta
      double precision :: detadx,detadxL,detadxR,detady,detadyT,detadyB
      double precision :: grad_eta


      integer :: i,j

      dry_tol = drytolerance
      gmod = grav
      rho = m0*rho_s + (1.0-m0)*rho_f

      do i=2-mbc,mx+mbc-1
         do j=2-mbc,my+mbc-1

            h = q(i,j,1)
            hL = q(i-1,j,1)
            hR = q(i+1,j,1)
            if (h<dry_tol) then
               aux(i,j,i_fsphi) = 1.0
               cycle
            endif

            hu = q(i,j,2)
            hv = q(i,j,3)
            hm = q(i,j,4)
            p  = q(i,j,5)

            if ((hu**2 + hv**2)==0.0) then
               aux(i,j,i_fsphi) = 1.0
               !cycle
            endif

            b = aux(i,j,1)
            bR = aux(i+1,j,1)
            bL = aux(i-1,j,1)
            phi = aux(i,j,i_phi)

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

            call admissibleq(h,hu,hv,hm,p,u,v,m,theta)
            pm = q(i,j,6)/q(i,j,1)
            call auxeval(h,u,v,m,p,phi,theta,kappa,S,rho,tanpsi,D,tau,sigbed,kperm,compress,pm)

            if (tau>0.0) then
               aux(i,j,i_fsphi) = min(1.0,grad_eta*rho*gmod*h/tau)
            else
               aux(i,j,i_fsphi) = 1.0
            endif
         enddo
      enddo

   end subroutine calc_tausplit

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
               aux(i,j,i_fs) = 10.0
               cycle
            endif

            hu = q(i,j,2)
            hv = q(i,j,3)

            if ((hu**2+hv**2)>0.0) then
               aux(i,j,i_fs) = 0.0
               cycle
            endif

            b = aux(i,j,1)
            bR = aux(i+1,j,1)
            bL = aux(i-1,j,1)
            phi = aux(i,j,i_phi)

            if ((phi)==0.0) then
               aux(i,j,i_fs) = 0.0
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
               aux(i,j,i_fs) = tan(phi)/grad_eta
            else
               aux(i,j,i_fs) = 10.0
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
